# Rollback

## EC2

Preservar o arquivo SQLite antes de mudanças de esquema. Fazer build do commit/tag anterior, enviar binário com o playbook Ansible via SSM, executar `/ready` e verificar `/version`. Reexecutar o playbook para provar idempotência. Não executar `terraform destroy` como rollback de app.

## EKS

`helm history web-app -n web-app`; `helm rollback web-app <revision> -n web-app --wait --timeout 10m`; `kubectl -n web-app rollout status deployment/web-app`. O deploy automatizado usa `helm upgrade --install --atomic --wait`. Como SQLite usa PVC e estratégia `Recreate`, haverá janela de indisponibilidade; rollback de código **não** desfaz alterações no banco. Manter schema compatível entre versões, com backup antes de migrações incompatíveis. `kubectl rollout undo` altera Deployment fora do histórico Helm: prefira `helm rollback`.

## Infraestrutura

Reverter código Terraform, revisar `plan` e aplicar somente depois de confirmar state, conta, custos e impacto. `prevent_destroy` protege bucket de state no bootstrap; não forçar sua remoção. PVC e StorageClass marcados `keep` exigem inventário/limpeza manual após destroy do laboratório.
