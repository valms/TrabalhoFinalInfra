# TrabalhoFinalInfra — laboratório público de infraestrutura

Laboratório AWS com dois caminhos independentes para a mesma API Go: **EC2 configurada com Ansible via SSM** e **EKS com Helm**. Terraform provisiona a infraestrutura; GitHub Actions mostra o pipeline público e `Jenkinsfile` é exemplo equivalente. Este repositório não prova que esses caminhos já foram implantados na AWS.

> This is a public laboratory project. Production banking implementations are confidential and are not included in this repository.

## Arquitetura

```text
Bootstrap Terraform → S3 state (versionado, lockfile) + S3 transferência Ansible (não versionado)
                          │
           ┌──────────────┴──────────────┐
           ▼                             ▼
  dev/prod: VPC → EC2              demo: VPC → EKS managed nodes
              SSM → Ansible                    ECR → Helm → Pod + EBS PVC
                     │                                    │
                     └──── app Go: CRUD SQLite ───────────┘
```

O root `terraform/` serve à EC2 dev/prod. Seu `backend.tf` é a única definição do backend S3; o EKS referencia esse arquivo por `terraform/eks/backend.tf` (link simbólico). Valores vêm de `terraform/env/{dev,prod}.tfvars`; `terraform init -backend-config` seleciona uma chave S3 distinta por alvo. EKS tem state próprio. `terraform/bootstrap` cria os buckets com state local separado (o bucket S3 não pode armazenar o próprio state antes de existir). A chave de dev preserva `trabalho-final/terraform.tfstate` do root original. **Não aplicar prod ou EKS sobre o state de dev.**

| Diretório | Uso |
| --- | --- |
| `app/` | Módulo `github.com/valms/TrabalhoFinalInfra/app`, servidor Go e Dockerfile |
| `ansible/` | Provisionamento idempotente da EC2 por SSM; NGINX proxy e serviço systemd |
| `terraform/` | Root EC2 existente: rede, SG, EC2/SSM e backend S3 compartilhado |
| `terraform/env/` | Valores dev/prod da EC2 (`*.tfvars.example`) |
| `terraform/bootstrap/` | Bucket de state e bucket temporário de transferência SSM |
| `terraform/eks/` | EKS, managed nodes, NAT, EBS CSI e ECR, state próprio |
| `helm/web-app/` | Chart EKS com uma réplica, PVC e probes |
| `tools/infra-check/` | CLI demonstrativa de diagnóstico |
| `docs/` | Baseline, roadmap, troubleshooting, rollback e incidente hipotético |

## Rodar API localmente

```sh
cd app
go test ./...
DB_PATH=./tasks.db LISTEN_ADDR=:8080 go run ./cmd/server
curl -X POST http://localhost:8080/tasks -H 'Content-Type: application/json' -d '{"title":"Testar Terraform"}'
curl http://localhost:8080/tasks
curl http://localhost:8080/ready
```

Endpoints: `POST /tasks`, `GET /tasks`, `GET /tasks/{id}`, `PUT /tasks/{id}` (JSON com `title` e `completed`), `DELETE /tasks/{id}`, `GET /health`, `GET /ready`, `GET /version`. SQLite persiste no caminho `DB_PATH`; `*.db*` não entra no Git.

## Preparar AWS e state

Requer Terraform compatível com `terraform/versions.tf`, AWS CLI, credenciais IAM com permissões explicitamente concedidas para recursos do laboratório, Ansible + coleção `amazon.aws`, Session Manager Plugin, Docker, Helm e kubectl. Preferir credenciais temporárias/OIDC no CI; workflow atual usa secrets AWS até configurar OIDC. O bucket histórico `unifor-terraform-state-trabalho-final` não foi encontrado na conta AWS consultada em 25/10/2026; confirme conta/região e crie/importe o backend antes do primeiro `init` remoto. Conferir conta antes de executar:

```sh
aws sts get-caller-identity
cp terraform/bootstrap/env/bootstrap.tfvars.example terraform/bootstrap/env/bootstrap.tfvars
# Edite nomes S3 globalmente únicos; se bucket de state legado já existir, importe-o antes de apply.
terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap plan -var-file=env/bootstrap.tfvars
```

Bucket de state legado pode já existir: importá-lo para `aws_s3_bucket.state` e os recursos separados de configuração após inspeção; nunca tentar criar outro com mesmo nome. Bucket de state tem `prevent_destroy` e histórico de versões; bucket SSM **não** é versionado e tem expiração de 1 dia. Runner Ansible precisa de `ssm:StartSession`, `ssm:TerminateSession` e permissões S3 `GetObject`, `PutObject`, `DeleteObject`, `ListBucket`, `GetBucketLocation` restritas ao bucket SSM. Role EC2 usa `AmazonSSMManagedInstanceCore`, sem chave SSH. Revisar IAM de EKS/ECR e permissões da conta antes de habilitar apply; ver [plugin Ansible SSM](https://docs.ansible.com/projects/ansible/latest/collections/amazon/aws/aws_ssm_connection.html).

## EC2 dev / prod

Para **cada** ambiente, copiar o exemplo de `tfvars` e conferir os valores. Bucket vem de `STATE_BUCKET`; chaves diferentes selecionam states distintos. Após verificar o state legado (veja `docs/roadmap.md`), executar dev:

```sh
cp terraform/env/dev.tfvars.example terraform/env/dev.tfvars
export STATE_BUCKET="nome-real-do-bucket-existente"
export TF_DATA_DIR="$PWD/.terraform-data/ec2-dev"
terraform -chdir=terraform init -reconfigure \
  -backend-config="bucket=$STATE_BUCKET" \
  -backend-config="key=trabalho-final/terraform.tfstate" \
  -backend-config="region=sa-east-1"
terraform -chdir=terraform validate
terraform -chdir=terraform plan -var-file=env/dev.tfvars
# Após revisar o plano: terraform -chdir=terraform apply -var-file=env/dev.tfvars
```

Para prod, copiar `env/prod.tfvars.example` para `env/prod.tfvars`, definir `TF_DATA_DIR="$PWD/.terraform-data/ec2-prod"`, usar `-backend-config="key=ec2/prod/terraform.tfstate"` no `init` e `-var-file=env/prod.tfvars` no `plan/apply`. Bucket e região são os mesmos do exemplo dev. **Valores diferentes sem chave de backend diferente não isolam state.** Diretórios `TF_DATA_DIR` separados evitam reutilizar metadados locais do backend ao trocar ambiente. Para deploy Ansible via SSM, compile `app/server-linux-amd64`, instale `amazon.aws` e Session Manager Plugin, exporte `AWS_REGION`, `ANSIBLE_SSM_BUCKET`, `TF_DATA_DIR` do ambiente escolhido e `TERRAFORM_DIR="$PWD/terraform"`; execute `scripts/generate-inventory.sh` e `ansible-playbook -i ansible/inventory.ini ansible/playbook.yml`. Aplique duas vezes e confirme idempotência. A EC2 usa NGINX como proxy para o app em `127.0.0.1:8080`; acesso HTTP é público, sem TLS neste laboratório.

## EKS + Helm

O EKS é **provisionado** no root `terraform/eks`, não depende da EC2 Ansible. Use o mesmo `STATE_BUCKET` com chave `eks-demo/terraform.tfstate` e defina `kubernetes_version` atualmente suportada e `allowed_api_cidrs` restritos em `terraform/eks/env/demo.tfvars` (exemplo no mesmo diretório). Não abrir API para `0.0.0.0/0`. Cluster, node group, NAT gateway, EBS, ECR e CloudWatch **geram custos mesmo com app ocioso**. Control plane e nodes têm ciclo de vida distinto do caminho EC2.

```sh
cp terraform/eks/env/demo.tfvars.example terraform/eks/env/demo.tfvars
# Ajuste versão suportada, CIDR da API e confirme duas zonas de disponibilidade existentes.
terraform -chdir=terraform/eks init -reconfigure \
  -backend-config="bucket=$STATE_BUCKET" \
  -backend-config="key=eks-demo/terraform.tfstate" \
  -backend-config="region=sa-east-1"
terraform -chdir=terraform/eks plan -var-file=env/demo.tfvars
# Após revisão: terraform -chdir=terraform/eks apply -var-file=env/demo.tfvars
aws eks update-kubeconfig --region sa-east-1 --name "$(terraform -chdir=terraform/eks output -raw cluster_name)"
helm lint helm/web-app
helm template web-app helm/web-app
helm upgrade --install web-app helm/web-app -n web-app --create-namespace \
  --set image.repository=SEU_ECR --set image.tag=SEU_COMMIT --wait --atomic --timeout 10m
kubectl -n web-app rollout status deployment/web-app
kubectl -n web-app port-forward service/web-app 8080:80
# Outro terminal: curl http://localhost:8080/ready
```

Publique imagem no ECR antes do Helm (`deploy.yml` demonstra build/push). PVC usa EBS CSI e StorageClass `gp3`; sem driver/role corretos, pod não fica ready. SQLite exige **uma réplica** e estratégia `Recreate`: breve interrupção no upgrade, sem promessa de zero downtime. PVC e StorageClass ficam retidos para proteção de dados; limpeza após destroy exige decisão explícita.

## CI, Jenkins e rollback

`.github/workflows/quality.yml` roda testes Go, fmt/validate Terraform, TFLint, Helm, Checkov e Gitleaks. `.github/workflows/deploy.yml` é **manual**, produz plano por alvo (`ec2-dev`, `ec2-prod`, `eks-demo`), aplica após gate de GitHub Environment, exige `DESTROY` para destruição, e faz deploy EC2 com Ansible ou EKS com Helm. Configure `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `STATE_BUCKET`, `ANSIBLE_SSM_BUCKET`, `EKS_KUBERNETES_VERSION`, `EKS_ALLOWED_API_CIDRS` e `EKS_AVAILABILITY_ZONES` (lista Terraform/HCL com duas zonas reais); crie ambientes protegidos no GitHub antes de liberar apply. Plano binário é artefato de curta retenção, potencialmente sensível; restringir acesso ao repositório/artefatos. Checkov possui exceções **por recurso**, justificadas no HCL para escolhas deste laboratório (HTTP público, bucket temporário sem versionamento e custos de logs/replicação/KMS). Não tratar isso como aprovação para produção.

`Jenkinsfile` mostra parâmetros `TARGET=ec2|eks`, `ENVIRONMENT=dev|prod|demo`, `ACTION=plan|apply|destroy`; `CONFIRM_DESTROY=DESTROY` é obrigatório para destroy. O agente precisa de `STATE_BUCKET`, de `TF_VAR_kubernetes_version`, `TF_VAR_allowed_api_cidrs` e `TF_VAR_availability_zones` para EKS, além de Terraform, Go, Docker, kubectl, Helm, Checkov, Gitleaks, Ansible, Session Manager Plugin, AWS CLI e credenciais/permissões fora do repositório. **The repository includes both GitHub Actions and Jenkins examples. The public repository uses GitHub Actions for demonstration, while Jenkins reflects the deployment model used in production environments.** Isso não afirma que este Jenkinsfile foi usado profissionalmente.

Leia `docs/troubleshooting.md` e `docs/rollback.md` antes de executar rollback; `docs/incident-example.md` é simulação. `helm rollback` recupera aplicação, não desfaz dados SQLite. Use `terraform plan -refresh-only` para investigar drift. `infra-check` em `tools/infra-check/README.md` é demonstrativo, sem alegar adoção por times.

Permissões e separação de roles: `docs/iam.md`. Lacunas e limites do grafo gerado: `docs/graph-gaps.md`.

## Linha do tempo e limites

Histórico anterior: 08–09/08/2026; fatos em `docs/current-state.md`. O commit desta ampliação está datado **10/08/2026 por solicitação**, embora o trabalho e a verificação tenham ocorrido em **25/10/2026**. Sem execução comprovada em AWS, não alegar deploy, disponibilidade, rollback automático na EC2, ALB ou número de times usuários. Não há ALB neste laboratório; exemplos de health usam `/ready`. Banco SQLite/EBS limita escala e não oferece HA; para múltiplas réplicas, migrar para banco externo compartilhado. Produção bancária não faz parte deste repositório.
