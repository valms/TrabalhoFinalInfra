# Troubleshooting

1. Identificar alvo e versão: `/version`, `infra-check version URL`, tag da imagem ou binário implantado.
2. EC2: consultar `aws ec2 describe-instance-status`, status SSM e resultado do Ansible; inspecionar `journalctl -u web-app` e `journalctl -u nginx` via SSM.
3. EKS: `kubectl -n web-app get pods,pvc`, `describe pod`, `get events`, `logs deployment/web-app`; verificar node, EBS CSI e se PVC está bound.
4. Testar `/health` e `/ready`; `/ready` confirma conexão SQLite. Verificar espaço em disco e permissões do diretório `/data` ou `/var/lib/web-app`.
5. Checar SG, rotas, endpoint do EKS e destino da conexão. Não há ALB provisionado neste laboratório; não alegar health check do ALB.
6. Comparar última versão estável e executar procedimento de `docs/rollback.md` quando necessário.

Para drift: `terraform -chdir=<root> plan -refresh-only`, inspecionando antes de qualquer alteração. State de cada root usa chave distinta.
