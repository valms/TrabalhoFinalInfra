# Estado anterior à ampliação do laboratório

Registro feito em 25/10/2026 a partir do código e do histórico Git local. Não confirma que recursos estejam ativos na AWS.

- `terraform/` era um root único, com VPC `10.0.0.0/16`, subnet pública, EC2 Ubuntu, EBS criptografado, IAM `AmazonSSMManagedInstanceCore` e SG com HTTP público e sem SSH.
- Backend S3: `trabalho-final/terraform.tfstate`, `encrypt=true`, `use_lockfile=true`; bucket/region eram injetados pela pipeline. Pipeline configurava bucket S3 com versionamento, AES256 e bloqueio público.
- `.github/workflows/deploy.yml` fazia deploy de NGINX pela API SSM com `scripts/deploy-via-ssm.sh`. `ansible/playbook.yml` existia, mas não era invocado pela pipeline.
- `README.md` descrevia fluxo SSH/Ansible anterior e não refletia o deploy real.
- Não havia cluster EKS, Helm, Jenkinsfile nem aplicação Go em `app/`.
- Histórico anterior vai de 08/08/2026 a 09/08/2026 (`git log --format='%h | %ad | %s' --date=iso-strict`); commits anteriores não foram alterados.

Próximos marcos: verificar state remoto e conta, importar bucket já existente para bootstrap quando cabível, testar os dois caminhos numa conta de laboratório e registrar evidências reais sem inventar execução.
