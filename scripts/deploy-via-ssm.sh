#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="${ROOT_DIR}/terraform"
INDEX_FILE="${ROOT_DIR}/ansible/files/index.html"

INSTANCE_ID="$(terraform -chdir="${TERRAFORM_DIR}" output -raw instance_id)"
PAGE_HTML_B64="$(base64 -w0 "${INDEX_FILE}")"

printf 'Aguardando instancia EC2 ficar running: %s\n' "${INSTANCE_ID}"
aws ec2 wait instance-running --instance-ids "${INSTANCE_ID}"

printf 'Aguardando instancia ficar online no AWS Systems Manager: %s\n' "${INSTANCE_ID}"
for attempt in {1..60}; do
  PING_STATUS="$(aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=${INSTANCE_ID}" \
    --query 'InstanceInformationList[0].PingStatus' \
    --output text)"

  if [ "${PING_STATUS}" = "Online" ]; then
    break
  fi

  if [ "${attempt}" -eq 60 ]; then
    printf 'Instancia %s nao ficou online no SSM. Ultimo status: %s\n' "${INSTANCE_ID}" "${PING_STATUS}" >&2
    exit 1
  fi

  sleep 10
done

COMMANDS_JSON="$(printf '["set -eu","export DEBIAN_FRONTEND=noninteractive","if command -v cloud-init >/dev/null 2>&1; then cloud-init status --wait; fi","if ! command -v nginx >/dev/null 2>&1; then apt-get update && apt-get install -y nginx; fi","tmp=$(mktemp)","printf %%s %s | base64 -d > ${tmp}","if ! cmp -s ${tmp} /var/www/html/index.html; then install -o root -g root -m 0644 ${tmp} /var/www/html/index.html && systemctl restart nginx; fi","rm -f ${tmp}","systemctl enable --now nginx"]' "${PAGE_HTML_B64}")"

COMMAND_ID="$(aws ssm send-command \
  --instance-ids "${INSTANCE_ID}" \
  --document-name "AWS-RunShellScript" \
  --comment "Deploy NGINX page" \
  --parameters "{\"commands\":${COMMANDS_JSON}}" \
  --query 'Command.CommandId' \
  --output text)"

if ! aws ssm wait command-executed \
  --command-id "${COMMAND_ID}" \
  --instance-id "${INSTANCE_ID}"; then
  aws ssm get-command-invocation \
    --command-id "${COMMAND_ID}" \
    --instance-id "${INSTANCE_ID}" \
    --query '{Status:Status,Stdout:StandardOutputContent,Stderr:StandardErrorContent}' \
    --output table
  exit 1
fi

aws ssm get-command-invocation \
  --command-id "${COMMAND_ID}" \
  --instance-id "${INSTANCE_ID}" \
  --query '{Status:Status,Stdout:StandardOutputContent,Stderr:StandardErrorContent}' \
  --output table
