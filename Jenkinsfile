pipeline {
    agent any
    options {
        timeout(time: 60, unit: 'MINUTES')
        disableConcurrentBuilds()
    }
    parameters {
        choice(name: 'TARGET', choices: ['ec2', 'eks'], description: 'Independent deployment path')
        choice(name: 'ENVIRONMENT', choices: ['dev', 'prod', 'demo'], description: 'dev/prod for EC2; demo for EKS')
        choice(name: 'ACTION', choices: ['plan', 'apply', 'destroy'], description: 'Terraform action')
        string(name: 'CONFIRM_DESTROY', defaultValue: '', description: 'Type DESTROY for destroy')
    }
    environment {
        TF_IN_AUTOMATION = 'true'
        TF_INPUT = 'false'
    }
    stages {
        stage('Checkout') {
            steps { checkout scm }
        }
        stage('Validate') {
            steps {
                sh 'terraform fmt -check -recursive terraform'
                sh 'go -C app test ./...'
                sh 'helm lint helm/web-app'
            }
        }
        stage('Security Scan') {
            steps {
                sh 'checkov -d terraform --framework terraform'
                sh 'gitleaks detect --config .gitleaks.toml --source . --no-git'
            }
        }
        stage('Plan') {
            steps {
                sh '''
                  : "${STATE_BUCKET:?Configure STATE_BUCKET in the Jenkins environment}"
                  if [ "${ACTION}" = destroy ] && [ "${CONFIRM_DESTROY}" != DESTROY ]; then exit 1; fi
                  if [ "${TARGET}" = eks ]; then
                    [ "${ENVIRONMENT}" = demo ] || exit 1
                    ROOT=terraform/eks
                    KEY=eks-demo/terraform.tfstate
                    VAR_FILE=
                  else
                    [ "${ENVIRONMENT}" != demo ] || exit 1
                    ROOT=terraform
                    VAR_FILE="-var-file=env/${ENVIRONMENT}.tfvars.example"
                    if [ "${ENVIRONMENT}" = dev ]; then KEY=trabalho-final/terraform.tfstate; else KEY=ec2/prod/terraform.tfstate; fi
                  fi
                  export TF_DATA_DIR="${WORKSPACE}/.terraform-data/${TARGET}-${ENVIRONMENT}"
                  terraform -chdir="$ROOT" init -reconfigure \
                    -backend-config="bucket=${STATE_BUCKET}" \
                    -backend-config="key=${KEY}" \
                    -backend-config="region=sa-east-1"
                  terraform -chdir="$ROOT" validate
                  if [ "${ACTION}" = destroy ]; then
                    terraform -chdir="$ROOT" plan ${VAR_FILE} -destroy -out=plan.tfplan
                  else
                    terraform -chdir="$ROOT" plan ${VAR_FILE} -out=plan.tfplan
                  fi
                '''
            }
        }
        stage('Approval') {
            when { expression { params.ACTION != 'plan' } }
            steps { input message: "${params.ACTION} ${params.ENVIRONMENT}?", ok: 'Approve' }
        }
        stage('Apply') {
            when { expression { params.ACTION != 'plan' } }
            steps {
                sh '''
                  if [ "${TARGET}" = eks ]; then ROOT=terraform/eks; else ROOT=terraform; fi
                  export TF_DATA_DIR="${WORKSPACE}/.terraform-data/${TARGET}-${ENVIRONMENT}"
                  terraform -chdir="$ROOT" apply plan.tfplan
                '''
            }
        }
        stage('Deploy') {
            when { expression { params.ACTION == 'apply' && params.TARGET == 'ec2' } }
            steps {
                sh '''
                  CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go -C app build -o server-linux-amd64 ./cmd/server
                  export TERRAFORM_DIR="${WORKSPACE}/terraform"
                  export TF_DATA_DIR="${WORKSPACE}/.terraform-data/ec2-${ENVIRONMENT}"
                  ./scripts/generate-inventory.sh
                  ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
                '''
            }
        }
        stage('Health Check') {
            when { expression { params.ACTION == 'apply' && params.TARGET == 'ec2' } }
            steps {
                sh '''
                  export TF_DATA_DIR="${WORKSPACE}/.terraform-data/ec2-${ENVIRONMENT}"
                  URL="$(terraform -chdir=terraform output -raw public_url)"
                  curl --fail --retry 12 --retry-delay 5 "$URL/ready"
                '''
            }
        }
        stage('Deploy EKS via Helm') {
            when { expression { params.ACTION == 'apply' && params.TARGET == 'eks' } }
            steps {
                sh '''
                  export TF_DATA_DIR="${WORKSPACE}/.terraform-data/eks-demo"
                  REPOSITORY="$(terraform -chdir=terraform/eks output -raw ecr_repository_url)"
                  REGISTRY="${REPOSITORY%%/*}"
                  TAG="$(git rev-parse HEAD)"
                  aws ecr get-login-password | docker login --username AWS --password-stdin "$REGISTRY"
                  docker build --build-arg "VERSION=$TAG" -t "$REPOSITORY:$TAG" app
                  docker push "$REPOSITORY:$TAG"
                  aws eks update-kubeconfig --name "$(terraform -chdir=terraform/eks output -raw cluster_name)" --region sa-east-1
                  helm upgrade --install web-app helm/web-app -n web-app --create-namespace \
                    --set "image.repository=$REPOSITORY" --set "image.tag=$TAG" --atomic --wait --timeout 10m
                  kubectl -n web-app rollout status deployment/web-app --timeout=10m
                '''
            }
        }
    }
    post {
        failure { echo 'Deployment failed; inspect plan, application logs, and documented rollback procedure.' }
    }
}
