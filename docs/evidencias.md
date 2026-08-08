# Linha do Tempo de Evidencias

Use este arquivo para colar prints ou trechos dos logs do GitHub Actions e do console da AWS.

## 1. Terraform Init

- Data/hora:
- Evidencia esperada: log do passo `Terraform init` concluido com sucesso.
- Print/log:

## 2. Terraform Validate

- Data/hora:
- Evidencia esperada: log do passo `Terraform validate` com configuracao valida.
- Print/log:

## 3. Terraform Plan

- Data/hora:
- Evidencia esperada: log do passo `Terraform plan` mostrando criacao da EC2, Key Pair e Security Group.
- Print/log:

## 4. Terraform Apply

- Data/hora:
- Evidencia esperada: log do passo `Terraform apply` concluido e outputs `public_ip`, `public_dns` e `public_url` disponiveis.
- Print/log:

## 5. Console da AWS

- Data/hora:
- Evidencia esperada: print da instancia EC2 em execucao na regiao `sa-east-1` e Security Group liberando HTTP e SSH conforme configurado.
- Print:

## 6. Inventario Ansible Gerado

- Data/hora:
- Evidencia esperada: `ansible/inventory.ini` gerado pelo script `scripts/generate-inventory.sh` usando o output `public_ip` do Terraform.
- Exemplo esperado:

```ini
[web]
web ansible_host=<public_ip> ansible_user=ubuntu ansible_ssh_private_key_file=<caminho_chave> ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

## 7. Execucao do Playbook Ansible

- Data/hora:
- Evidencia esperada: log do passo `Executar playbook Ansible` instalando NGINX, publicando a pagina e garantindo servico ativo.
- Print/log:

## 8. Segunda Execucao do Playbook

- Data/hora:
- Evidencia esperada: log do passo `Validar idempotencia Ansible` com `changed=0`.
- Print/log:

## 9. Aplicacao no Ar

- Data/hora:
- URL publica:
- Evidencia esperada: print da pagina `Trabalho Final Integrador` acessivel via HTTP.
- Print:

## 10. Terraform Destroy

- Data/hora:
- Evidencia esperada: log do passo `Terraform destroy infraestrutura principal` concluido com sucesso.
- Print/log:

## 11. Pos-Destroy no Console AWS

- Data/hora:
- Evidencia esperada: print do console da AWS mostrando ausencia da instancia EC2 ativa do projeto.
- Print:
