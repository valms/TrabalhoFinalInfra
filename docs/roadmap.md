# Roadmap do laboratório

1. Verificar AWS e state legado antes de qualquer migração ou `apply`.
2. Bootstrap: adotar bucket S3 existente por importação, após revisão; transferências SSM em bucket separado e sem versionamento.
3. Preservar o state legado em `trabalho-final/terraform.tfstate` ao usar o root original `terraform/` para dev. Conferir recursos e plano antes de aplicar; `env/dev.tfvars` altera a tag Environment de `academic` para `dev`. Prod usa o mesmo root com `env/prod.tfvars` e chave separada `ec2/prod/terraform.tfstate`. EKS usa root próprio e chave separada.
4. Executar EC2 dev e provar Ansible via SSM, idempotência e CRUD persistente. Só depois habilitar prod.
5. Provisionar EKS em `terraform/eks` após conferir custos: cluster, node, NAT gateway, EBS, logs e tráfego. Helm necessita imagem publicada no ECR.
6. Exercitar deploy, falha de readiness, rollback de aplicação e limpeza dos volumes persistentes conforme política de retenção.
7. Revisar permissões IAM, alertas, proteção do ambiente prod, Checkov e Gitleaks antes de habilitar deploy de produção.

## Migração do state legado

Consultar `terraform -chdir=terraform state list` **somente após init apontando ao bucket/key correto**; preservar backup do state e conferir conta/region via `aws sts get-caller-identity`. O root EC2 mantém os endereços originais; verificar se o state existente corresponde aos recursos antes do primeiro apply. Prod e EKS não podem compartilhar a chave legada. O bucket de state não pode ser destruído junto com os consumidores.
