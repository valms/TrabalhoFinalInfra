# Trabalho Final Integrador - Terraform, AWS e Ansible

Projeto para provisionar uma instancia EC2 na AWS com Terraform e configurar um servidor web NGINX com Ansible.

## Arquitetura

- AWS Region: `sa-east-1` Sao Paulo
- Terraform bootstrap: cria bucket S3 para armazenar `terraform.tfstate`
- Terraform principal: cria Key Pair, Security Group e EC2 Ubuntu
- Ansible: instala e configura NGINX de forma idempotente
- GitHub Actions: executa deploy manual e destroy opcional

## Pre-requisitos Locais

- Conta AWS com credenciais configuradas
- Terraform instalado
- Ansible instalado
- Chave SSH local

Crie a chave SSH local:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/unifor-terraform
```

## 1. Bootstrap do State Remoto

O backend S3 precisa existir antes do Terraform principal usar o state remoto.

```bash
terraform -chdir=bootstrap init
terraform -chdir=bootstrap plan
terraform -chdir=bootstrap apply
```

Anote o output `state_bucket_name`.

Copie o exemplo de backend:

```bash
cp terraform/backend.hcl.example terraform/backend.hcl
```

Se necessario, ajuste o bucket em `terraform/backend.hcl`.

## 2. Deploy da Infraestrutura

Copie o exemplo de variaveis:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Preencha `public_key` com:

```bash
cat ~/.ssh/unifor-terraform.pub
```

Execute:

```bash
terraform -chdir=terraform init -backend-config=backend.hcl
terraform -chdir=terraform plan
terraform -chdir=terraform apply
```

## 3. Inventario Ansible via Terraform Output

```bash
./scripts/generate-inventory.sh
```

## 4. Execucao do Playbook

Primeira execucao:

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

Segunda execucao para provar idempotencia:

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

Resultado esperado na segunda execucao: `changed=0`.

## 5. Aplicacao no Ar

Use o output do Terraform:

```bash
terraform -chdir=terraform output public_url
```

Abra a URL no navegador e registre evidencia.

## 6. Destroy

Destruir apenas a infraestrutura principal:

```bash
terraform -chdir=terraform destroy
```

Destruir tudo, incluindo bootstrap do S3:

```bash
./scripts/destroy-all.sh
```

## Pipeline GitHub Actions

Workflow: `.github/workflows/deploy.yml`.

Secrets necessarios:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `EC2_SSH_PRIVATE_KEY`
- `TF_VAR_PUBLIC_KEY`

Execucao manual:

- `action=deploy`: provisiona EC2 e roda Ansible
- `action=destroy`: destrói recursos principais
- `destroy_bootstrap=true`: tambem destrói bucket S3 do state
- `confirm_destroy=DESTROY`: confirmacao obrigatoria para destroy

## Higiene

- `terraform.tfvars`, states e inventario gerado nao entram no Git.
- Chave privada SSH nao entra no Git.
- `terraform destroy` deve ser registrado em `docs/evidencias.md`.
