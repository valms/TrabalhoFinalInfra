# Trabalho Final Integrador - Terraform, AWS e Ansible

Projeto para provisionar uma instancia EC2 na AWS com Terraform e configurar um servidor NGINX com Ansible, publicando uma pagina web acessivel pela internet.

## Objetivo

Atender ao trabalho final integrador com uma entrega organizada, segura e demonstravel por evidencias.

- Terraform cria a infraestrutura AWS.
- Ansible configura o servidor e publica a pagina web.
- Output do Terraform alimenta o inventario do Ansible.
- GitHub Actions executa deploy, validacao de idempotencia e destroy.
- Evidencias ficam organizadas em linha do tempo.

## Criterios Atendidos

- Codigo Terraform funcional e organizado em arquivos `.tf` por responsabilidade.
- Playbook Ansible idempotente, com validacao automatica de `changed=0` na segunda execucao.
- Integracao Terraform-Ansible via `terraform output` e script de inventario.
- Linha do tempo de evidencias em `docs/evidencias.md`.
- Higiene de ambiente com `terraform destroy`, `.gitignore` para estados, inventarios e chaves, e secrets fora do codigo.

## Arquitetura

Fluxo principal:

```text
GitHub Actions
  -> prepara credenciais AWS e chave SSH
  -> cria/valida bucket S3 do state
  -> terraform init / validate / plan / apply
  -> gera inventario Ansible com terraform output
  -> aguarda SSH
  -> executa playbook Ansible
  -> executa playbook novamente para validar changed=0
  -> exibe URL publica
  -> destroy manual ao final
```

Arquitetura AWS:

```text
VPC dedicada 10.0.0.0/16
  -> Subnet publica 10.0.1.0/24
    -> EC2 Ubuntu
      -> NGINX
      -> pagina em /var/www/html/index.html

Internet Gateway
  -> Route Table publica
    -> rota 0.0.0.0/0 para acesso HTTP publico

Security Group
  -> entrada HTTP 80: 0.0.0.0/0
  -> entrada SSH 22: somente IP publico do runner GitHub Actions /32
  -> saida TCP 80 e 443 para atualizacao de pacotes
```

## Organizacao do Projeto

```text
.
├── .github/workflows/deploy.yml
├── ansible/
│   ├── files/index.html
│   └── playbook.yml
├── docs/
│   └── evidencias.md
├── scripts/
│   └── generate-inventory.sh
└── terraform/
    ├── backend.tf
    ├── data.tf
    ├── key_pair.tf
    ├── locals.tf
    ├── main.tf
    ├── network.tf
    ├── outputs.tf
    ├── provider.tf
    ├── security.tf
    ├── variables.tf
    └── versions.tf
```

## Abordagem Terraform

O Terraform foi separado por responsabilidade para facilitar leitura, correcao e apresentacao. O arquivo `main.tf` nao concentra mais toda a infraestrutura; ele fica apenas com a EC2.

### Versoes e Provider

O arquivo `terraform/versions.tf` fixa a versao minima do Terraform e a familia do AWS Provider.

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

O provider usa a regiao definida em variavel e aplica tags padrao em todos os recursos suportados.

```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
```

### State Remoto

O state fica em S3 para evitar depender de estado local da maquina ou do runner. O bucket e preparado pela pipeline antes do `terraform init`.

```hcl
terraform {
  backend "s3" {
    bucket       = "unifor-terraform-state-trabalho-final"
    key          = "trabalho-final/terraform.tfstate"
    region       = "sa-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

### Tags Padrao

Tags comuns ajudam a identificar recursos no console AWS e comprovam que os recursos pertencem ao trabalho.

```hcl
locals {
  common_tags = {
    Project     = var.project_name
    ManagedBy   = "terraform"
    Environment = var.environment
  }
}
```

### AMI Ubuntu

A AMI nao fica hardcoded. O Terraform busca a imagem Ubuntu 22.04 mais recente do owner oficial da Canonical.

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
```

### EC2

A EC2 fica na subnet publica da VPC do projeto. O volume raiz usa `gp3` e criptografia ativada.

```hcl
resource "aws_instance" "web" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.this.key_name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-web"
  }
}
```

## Abordagem de Rede

Foi criada uma VPC dedicada em vez de usar a VPC default da conta AWS. Isso melhora isolamento, deixa a arquitetura mais explicita e gera evidencias melhores para o trabalho.

### VPC e Subnet Publica

```hcl
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr_block
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}
```

### Internet Gateway e Route Table

Como a pagina precisa ficar acessivel pela internet, a subnet publica recebe uma rota default para o Internet Gateway.

```hcl
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
```

## Abordagem de Seguranca

A pagina precisa ser publica, mas isso nao significa liberar tudo. A abordagem adotada e manter HTTP publico e restringir SSH.

### Security Group na VPC

O Security Group pertence explicitamente a VPC criada pelo Terraform.

```hcl
resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Permite HTTP publico e SSH restrito para o trabalho final"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}
```

### HTTP Publico

HTTP fica aberto para `0.0.0.0/0` porque esse e o requisito funcional: a aplicacao deve estar no ar e acessivel publicamente.

```hcl
resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  description       = "HTTP"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}
```

### SSH Restrito

SSH nao usa `0.0.0.0/0`. A variavel vem vazia por padrao e bloqueia explicitamente SSH aberto para a internet.

```hcl
variable "allowed_ssh_cidr_blocks" {
  description = "Blocos CIDR permitidos para acesso SSH. Use apenas IPs publicos especificos com /32."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.allowed_ssh_cidr_blocks :
      can(cidrnetmask(cidr)) && cidr != "0.0.0.0/0"
    ])
    error_message = "allowed_ssh_cidr_blocks deve conter CIDRs IPv4 validos e nao pode liberar SSH para 0.0.0.0/0."
  }
}
```

A regra SSH usa somente os CIDRs permitidos.

```hcl
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = toset(var.allowed_ssh_cidr_blocks)

  security_group_id = aws_security_group.web.id
  description       = "SSH"
  cidr_ipv4         = each.value
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}
```

Na pipeline, o IP publico do runner e descoberto e enviado ao Terraform como `/32`.

```yaml
- name: Preparar chave SSH
  env:
    EC2_SSH_PRIVATE_KEY: ${{ secrets.EC2_SSH_PRIVATE_KEY }}
  run: |
    mkdir -p ~/.ssh
    printf '%s\n' "${EC2_SSH_PRIVATE_KEY}" > ~/.ssh/unifor-terraform
    chmod 600 ~/.ssh/unifor-terraform
    PUBLIC_KEY="$(ssh-keygen -y -f ~/.ssh/unifor-terraform)"
    printf 'TF_VAR_public_key=%s\n' "${PUBLIC_KEY}" >> "${GITHUB_ENV}"

    RUNNER_PUBLIC_IP="$(curl -fsSL https://checkip.amazonaws.com | tr -d '[:space:]')"
    printf 'TF_VAR_allowed_ssh_cidr_blocks=["%s/32"]\n' "${RUNNER_PUBLIC_IP}" >> "${GITHUB_ENV}"
```

### Egress Restrito

A saida da EC2 nao fica totalmente aberta. Para este trabalho, basta permitir HTTP e HTTPS para atualizacao de pacotes e instalacao do NGINX.

```hcl
resource "aws_vpc_security_group_egress_rule" "http_ipv4" {
  security_group_id = aws_security_group.web.id
  description       = "Saida HTTP para atualizacao de pacotes"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "https_ipv4" {
  security_group_id = aws_security_group.web.id
  description       = "Saida HTTPS para atualizacao de pacotes"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}
```

## Abordagem de Chave SSH

A AWS recebe apenas a chave publica. A chave privada fica no GitHub Secret e e usada apenas pelo Ansible para acessar a EC2.

Geracao local da chave:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/unifor-terraform
```

Cadastro do secret:

```bash
cat ~/.ssh/unifor-terraform
```

O Terraform registra a chave publica como Key Pair EC2.

```hcl
resource "aws_key_pair" "this" {
  key_name   = var.key_name
  public_key = var.public_key
}
```

## Abordagem Ansible

O playbook usa modulos declarativos do Ansible. Isso favorece idempotencia: se o estado ja estiver correto, a segunda execucao nao deve alterar nada.

```yaml
---
- name: Configure NGINX web server
  hosts: web
  become: true
  gather_facts: true

  handlers:
    - name: Restart nginx
      ansible.builtin.service:
        name: nginx
        state: restarted

  tasks:
    - name: Update apt cache
      ansible.builtin.apt:
        update_cache: true
        cache_valid_time: 3600

    - name: Install nginx
      ansible.builtin.apt:
        name: nginx
        state: present

    - name: Publish web page
      ansible.builtin.copy:
        src: files/index.html
        dest: /var/www/html/index.html
        owner: root
        group: root
        mode: "0644"
      notify: Restart nginx

    - name: Ensure nginx is enabled and running
      ansible.builtin.service:
        name: nginx
        state: started
        enabled: true
```

Decisoes importantes:

- `apt state=present`: instala NGINX apenas se ele ainda nao estiver instalado.
- `copy`: altera a pagina apenas se o conteudo, dono, grupo ou modo forem diferentes.
- `notify`: reinicia NGINX somente quando a pagina muda.
- `service state=started enabled=true`: garante servico ativo e habilitado no boot.
- `cache_valid_time=3600`: evita atualizar cache apt desnecessariamente em execucoes proximas.

## Integracao Terraform e Ansible

O Ansible nao recebe IP fixo manual. O inventario e gerado a partir dos outputs do Terraform.

Outputs relevantes:

```hcl
output "public_ip" {
  description = "IP publico usado pelo inventario do Ansible."
  value       = aws_instance.web.public_ip
}

output "ssh_user" {
  description = "Usuario SSH padrao das AMIs Ubuntu."
  value       = "ubuntu"
}
```

Script de inventario:

```bash
PUBLIC_IP="$(terraform -chdir="${TERRAFORM_DIR}" output -raw public_ip)"
SSH_USER="$(terraform -chdir="${TERRAFORM_DIR}" output -raw ssh_user)"

{
  printf '[web]\n'
  printf "web ansible_host=%s ansible_user=%s ansible_ssh_private_key_file=%s ansible_ssh_common_args='-o StrictHostKeyChecking=no'\n" \
    "${PUBLIC_IP}" \
    "${SSH_USER}" \
    "${SSH_KEY_FILE}"
} > "${INVENTORY_FILE}"
```

Inventario gerado esperado:

```ini
[web]
web ansible_host=<public_ip> ansible_user=ubuntu ansible_ssh_private_key_file=/home/runner/.ssh/unifor-terraform ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

## Validacao de Idempotencia

A pipeline roda o playbook duas vezes. A segunda execucao deve terminar com `changed=0`; se nao terminar, o workflow falha.

```yaml
- name: Validar idempotencia Ansible
  run: |
    set -o pipefail
    ansible-playbook -i ansible/inventory.ini ansible/playbook.yml | tee ansible-second-run.log
    if ! grep -Eq 'changed=0[[:space:]]+' ansible-second-run.log; then
      printf 'Playbook nao ficou idempotente: segunda execucao teve changed diferente de 0.\n'
      exit 1
    fi
```

## Deploy Pela Pipeline

Workflow: `.github/workflows/deploy.yml`.

Execucao automatica:

- Push na branch `feature/infra-ec2-ansible` executa deploy.

Execucao manual:

- `action=deploy`: cria S3 do state, executa Terraform e roda Ansible.
- `action=destroy`: destroi a infraestrutura principal.
- `confirm_destroy=DESTROY`: confirmacao obrigatoria para destroy.
- `destroy_bootstrap=true`: remove tambem o bucket S3 de state.

Passos principais da pipeline:

```yaml
- name: Terraform init
  run: terraform -chdir=terraform init

- name: Terraform validate
  run: terraform -chdir=terraform validate

- name: Terraform plan
  run: terraform -chdir=terraform plan

- name: Terraform apply
  run: terraform -chdir=terraform apply -auto-approve

- name: Gerar inventario Ansible
  run: ./scripts/generate-inventory.sh

- name: Executar playbook Ansible
  run: ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

## Destroy Pela Pipeline

Use o destroy ao final da apresentacao para cumprir a higiene de ambiente e evitar custos na AWS.

Passo a passo:

1. Acesse o repositorio no GitHub.
2. Abra a aba `Actions`.
3. Selecione o workflow `Deploy Infraestrutura AWS`.
4. Clique em `Run workflow`.
5. Em `Use workflow from`, selecione a branch que contem o workflow.
6. Em `action`, selecione `destroy`.
7. Em `confirm_destroy`, digite exatamente `DESTROY`.
8. Em `destroy_bootstrap`, escolha se o bucket S3 de state tambem sera removido.
9. Clique em `Run workflow`.

Opcoes de destroy:

- `destroy_bootstrap=false`: remove apenas a infraestrutura principal criada pelo Terraform, como EC2, VPC, subnet, Internet Gateway, Route Table, Security Group e Key Pair.
- `destroy_bootstrap=true`: remove a infraestrutura principal e tambem apaga o bucket S3 usado pelo state remoto.

O workflow exige `confirm_destroy=DESTROY` para evitar destruicao acidental.

## Evidencias Para Apresentacao

Use os logs do GitHub Actions e preencha `docs/evidencias.md` com:

- `terraform init`.
- `terraform validate`.
- `terraform plan`.
- `terraform apply`.
- console da AWS mostrando VPC, subnet, EC2 e Security Group.
- inventario gerado pelo output do Terraform.
- primeira execucao do playbook.
- segunda execucao do playbook com `changed=0`.
- URL publica da aplicacao.
- `terraform destroy`.

## Secrets Obrigatorios

Cadastre em `Settings > Secrets and variables > Actions`:

- `AWS_ACCESS_KEY_ID`.
- `AWS_SECRET_ACCESS_KEY`.
- `EC2_SSH_PRIVATE_KEY`.

`AWS_REGION` ja esta definido no workflow como `sa-east-1`.

## Higiene

- Nenhuma chave privada entra no Git.
- Nenhum `tfstate` entra no Git.
- Nenhum `tfvars` entra no Git.
- Inventario Ansible gerado nao entra no Git.
- Credenciais AWS ficam em GitHub Secrets.
- SSH nao fica aberto para `0.0.0.0/0`.
- Recursos AWS devem ser removidos ao final com `action=destroy`.
