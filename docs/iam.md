# Permissões IAM a configurar para pipelines

Não usar role EC2 para deploy. Criar roles separadas por ambiente e workload; preferir OIDC com trust limitado por repositório/ref e GitHub Environment. O workflow público ainda usa secrets AWS; migrar para OIDC antes de uso persistente.

## Backend state

- `s3:ListBucket` no bucket de state, condicionado ao prefixo da chave do ambiente.
- `s3:GetObject`, `s3:PutObject` na chave legada `trabalho-final/terraform.tfstate` (dev), `ec2/prod/terraform.tfstate` ou `eks-demo/terraform.tfstate` da role correspondente.
- `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` no objeto `<key>.tflock` para locking S3; não conceder `DeleteObject` na chave do state.
- Se usar bootstrap com state local, manter backup cifrado e acesso restrito; bucket de state protegido contra destroy.

## Ansible SSM

Permitir `ssm:StartSession`, `ssm:TerminateSession` e consulta de status apenas para instância-alvo e documento da sessão necessários. No bucket **separado, não versionado** de transferência: `s3:GetBucketLocation`, `s3:ListBucket` no bucket e `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` no prefixo da instância. A instância precisa de `AmazonSSMManagedInstanceCore` e conectividade HTTPS/S3; SSH não é aberto.

## Provisionamento/deploy

Terraform requer permissões AWS específicas para VPC, EC2, IAM/PassRole, EKS, ECR, NAT, EBS e logs conforme o root. Evitar credencial compartilhada entre prod e demo; confirmar políticas com CloudTrail/Access Analyzer após os primeiros planos. Deploy EKS precisa de autenticação no cluster (access entry/role), ECR push e permissões Kubernetes no namespace; IAM AWS isolado não dá RBAC Kubernetes. `terraform plan` pode consultar AWS sem permissão de escrita de infraestrutura, mas precisa do lock S3.
