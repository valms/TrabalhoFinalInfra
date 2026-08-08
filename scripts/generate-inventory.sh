#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="${ROOT_DIR}/terraform"
INVENTORY_FILE="${ROOT_DIR}/ansible/inventory.ini"
SSH_KEY_FILE="${SSH_KEY_FILE:-${HOME}/.ssh/unifor-terraform}"

PUBLIC_IP="$(terraform -chdir="${TERRAFORM_DIR}" output -raw public_ip)"
SSH_USER="$(terraform -chdir="${TERRAFORM_DIR}" output -raw ssh_user)"

mkdir -p "$(dirname "${INVENTORY_FILE}")"

{
  printf '[web]\n'
  printf "web ansible_host=%s ansible_user=%s ansible_ssh_private_key_file=%s ansible_ssh_common_args='-o StrictHostKeyChecking=no'\n" \
    "${PUBLIC_IP}" \
    "${SSH_USER}" \
    "${SSH_KEY_FILE}"
} > "${INVENTORY_FILE}"

printf 'Inventory generated at %s\n' "${INVENTORY_FILE}"
