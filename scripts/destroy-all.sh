#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf 'This will destroy Terraform resources in terraform/ and bootstrap/.\n'
printf 'Type DESTROY to continue: '
read -r CONFIRMATION

if [[ "${CONFIRMATION}" != "DESTROY" ]]; then
  printf 'Destroy cancelled.\n'
  exit 1
fi

terraform -chdir="${ROOT_DIR}/terraform" destroy
terraform -chdir="${ROOT_DIR}/bootstrap" destroy
