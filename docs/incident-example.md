# Exemplo hipotético de incidente (não é ocorrência real)

**Sintoma:** novo pod não fica ready após deploy Helm. `helm upgrade --atomic --wait` expira.

1. `kubectl -n web-app describe pod ...` mostra PVC pendente.
2. Consultar eventos de StorageClass e pods do EBS CSI; validar IAM de Pod Identity e topologia da zona.
3. Verificar `/ready` somente depois do volume montado. Não marcar indisponibilidade do SQLite como falha de ALB (não existe ALB no exemplo).
4. Helm desfaz release mal-sucedida quando `--atomic` falha; conferir `helm history` e `/version`.
5. Corrigir provisionamento e repetir deploy com plano de rollback.

Este roteiro serve para treino; só registrar evidências reais após executar em AWS.
