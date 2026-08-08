# Linha do Tempo de Evidencias

Use este arquivo para registrar prints, comandos e resultados do trabalho final.

## 1. Terraform Init

- Data/hora:
- Comando:
  ```bash
  terraform -chdir=terraform init -backend-config=backend.hcl
  ```
- Evidencia:

## 2. Terraform Plan

- Data/hora:
- Comando:
  ```bash
  terraform -chdir=terraform plan
  ```
- Evidencia:

## 3. Terraform Apply

- Data/hora:
- Comando:
  ```bash
  terraform -chdir=terraform apply
  ```
- Outputs relevantes:
  ```bash
  terraform -chdir=terraform output
  ```
- Evidencia:

## 4. Console da AWS

- Data/hora:
- Evidencias esperadas:
  - EC2 criada em `sa-east-1`
  - Security Group com portas `22` e `80`
  - S3 bucket do state remoto

## 5. Inventario Ansible Gerado

- Data/hora:
- Comando:
  ```bash
  ./scripts/generate-inventory.sh
  ```
- Evidencia:

## 6. Execucao do Playbook

- Data/hora:
- Comando:
  ```bash
  ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
  ```
- Evidencia:

## 7. Segunda Execucao do Playbook

- Data/hora:
- Comando:
  ```bash
  ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
  ```
- Resultado esperado: `changed=0`
- Evidencia:

## 8. Aplicacao no Ar

- Data/hora:
- URL:
- Evidencia:

## 9. Destroy

- Data/hora:
- Comando:
  ```bash
  terraform -chdir=terraform destroy
  ```
- Evidencia:

## 10. Ausencia de Segredos

- Data/hora:
- Evidencias:
  - `terraform.tfvars` nao versionado
  - chave privada nao versionada
  - secrets usados somente localmente ou no GitHub Actions
