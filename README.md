# Trabalho Final Integrador - Terraform, AWS e Ansible

Projeto para provisionar uma instancia EC2 na AWS com Terraform e configurar NGINX com Ansible.

## Entrega

- Terraform organizado em `terraform/main.tf`, `terraform/variables.tf` e `terraform/outputs.tf`.
- State remoto em S3: `unifor-terraform-state-trabalho-final`.
- EC2 Ubuntu em `sa-east-1` com Security Group para SSH e HTTP.
- Key Pair criada pelo Terraform a partir da chave publica derivada no runner.
- Inventario Ansible gerado pelo output `public_ip` do Terraform.
- Playbook Ansible idempotente com NGINX e pagina web.
- Pipeline GitHub Actions cria, configura, valida e destrói os recursos.

## Secrets Obrigatorios

Cadastre em `Settings > Secrets and variables > Actions`:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `EC2_SSH_PRIVATE_KEY`

`AWS_REGION` ja esta definido no workflow como `sa-east-1`.

## Chave SSH

Sim, voce precisa gerar uma chave SSH uma vez. A AWS recebe apenas a chave publica; a chave privada fica no GitHub Secret para o Ansible acessar a EC2.

Gere a chave:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/unifor-terraform
```

Cadastre o conteudo inteiro da chave privada no secret `EC2_SSH_PRIVATE_KEY`:

```bash
cat ~/.ssh/unifor-terraform
```

O workflow deriva a chave publica com `ssh-keygen -y` e alimenta `var.public_key` no Terraform. A chave privada nunca entra no repositorio.

## Deploy Pela Pipeline

Workflow: `.github/workflows/deploy.yml`.

Execucao automatica:

- Push na branch `feature/infra-ec2-ansible` executa deploy.

Execucao manual:

- `action=deploy`: cria S3 do state, executa Terraform e roda Ansible.
- `action=destroy`: destrói a infraestrutura principal.
- `confirm_destroy=DESTROY`: confirmacao obrigatoria para destroy.
- `destroy_bootstrap=true`: remove tambem o bucket S3 de state.

## Evidencias Para Apresentacao

Use os logs do GitHub Actions e preencha `docs/evidencias.md` com:

- `terraform init`
- `terraform validate`
- `terraform plan`
- `terraform apply`
- console da AWS
- inventario gerado pelo output do Terraform
- execucao do playbook
- segunda execucao do playbook com `changed=0`
- URL publica da aplicacao
- `terraform destroy`

## Higiene

- Nenhuma chave privada entra no Git.
- Nenhum `tfstate` entra no Git.
- Inventario Ansible gerado nao entra no Git.
- Recursos AWS devem ser removidos ao final com `action=destroy`.
