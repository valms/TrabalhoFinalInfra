#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="${ROOT_DIR}/terraform"
INDEX_FILE="${ROOT_DIR}/ansible/files/index.html"

INSTANCE_ID="$(terraform -chdir="${TERRAFORM_DIR}" output -raw instance_id)"
PAGE_HTML_B64="$(base64 -w0 "${INDEX_FILE}")"

COMMANDS_JSON="$(jq -nc --arg html "${PAGE_HTML_B64}" '[
  "set -euo pipefail",
  "export DEBIAN_FRONTEND=noninteractive",
  "if ! command -v nginx >/dev/null 2>&1; then apt-get update && apt-get install -y nginx; fi",
  "tmp=$(mktemp)",
  "printf %s \"" + $html + "\" | base64 -d > ${tmp}",
  "if ! cmp -s ${tmp} /var/www/html/index.html; then install -o root -g root -m 0644 ${tmp} /var/www/html/index.html && systemctl restart nginx; fi",
  "rm -f ${tmp}",
  "systemctl enable --now nginx"
]')"

COMMAND_ID="$(aws ssm send-command \
  --instance-ids "${INSTANCE_ID}" \
  --document-name "AWS-RunShellScript" \
  --comment "Deploy NGINX page" \
  --parameters "{\"commands\":${COMMANDS_JSON}}" \
  --query 'Command.CommandId' \
  --output text)"

aws ssm wait command-executed \
  --command-id "${COMMAND_ID}" \
  --instance-id "${INSTANCE_ID}"

aws ssm get-command-invocation \
  --command-id "${COMMAND_ID}" \
  --instance-id "${INSTANCE_ID}" \
  --query '{Status:Status,Stdout:StandardOutputContent,Stderr:StandardErrorContent}' \
  --output table
