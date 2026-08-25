#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="${TERRAFORM_DIR:-${ROOT_DIR}/terraform}"
INVENTORY_FILE="${ROOT_DIR}/ansible/inventory.ini"
: "${ANSIBLE_SSM_BUCKET:?Set ANSIBLE_SSM_BUCKET to the dedicated, unversioned transfer bucket}"
: "${AWS_REGION:?Set AWS_REGION}"

INSTANCE_ID="$(terraform -chdir="${TERRAFORM_DIR}" output -raw instance_id)"

{
  printf '[web]\n'
  printf '%s ansible_connection=amazon.aws.aws_ssm ansible_aws_ssm_bucket_name=%s ansible_aws_ssm_region=%s\n' \
    "${INSTANCE_ID}" "${ANSIBLE_SSM_BUCKET}" "${AWS_REGION}"
} > "${INVENTORY_FILE}"

printf 'Inventory generated at %s\n' "${INVENTORY_FILE}"
