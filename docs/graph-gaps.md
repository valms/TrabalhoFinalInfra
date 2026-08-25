# Lacunas do grafo e da demonstração

O relatório local `graphify-out/GRAPH_REPORT.md` (gerado por `/graphify`, não versionado) descreve um snapshot anterior à última limpeza dos outputs Terraform e dos values Helm; não é validação em AWS. Aquela execução encontrou 210 nós, 350 relações, 23 comunidades e 46 relações com endpoint ausente. A contagem de tokens do agente não estava disponível; zero significa **não medido**. Regerar o grafo antes de usá-lo como mapa exato dos arquivos atuais.

## Lacunas na extração

- `helm/web-app/templates/serviceaccount.yaml` foi ignorado pelo detector como sensível, embora seja um manifesto de ServiceAccount; sua participação no deployment não foi extraída. Revisar a classificação antes de forçar inclusão.
- 28 nós foram classificados como isolados ou quase isolados. Vários são locks de providers ou módulos Go: isolamento pode ser limite do parser, não defeito de arquitetura.
- `scripts/deploy-via-ssm.sh` era caminho legado sem consumidores atuais. Script e página NGINX legada foram removidos; `docs/current-state.md` preserva o registro histórico.
- `scripts/generate-inventory.sh` é chamado pelo workflow e Jenkins, mas o grafo não necessariamente extrai chamadas de shell/YAML. Conferir as chamadas nos arquivos antes de concluir que ele está órfão.
- `terraform/backend.tf` e o link simbólico `terraform/eks/backend.tf` não produzem símbolos no extrator AST: o grafo não comprova a separação das chaves S3. Ela está definida nos exemplos de backend e nos pipelines.
- Comunidades Terraform com coesão baixa não justificam, por si só, reintroduzir `modules/`: os recursos EC2 usam um único root e mantêm endereços de state históricos.
- O grafo descreve relações extraídas, mas o detector omite parte do código e suas arestas; conferir relações críticas no código-fonte.

## Evidências ainda ausentes no laboratório

- Sem execução comprovada de `terraform plan/apply` para EC2 e EKS na conta AWS com o state legado inspecionado.
- Sem prova de segundo run idempotente do Ansible via SSM nem exercício real de rollback EC2/EKS.
- Permissões IAM mínimas, aprovação de prod e scans existem como configuração/documentação, mas não há evidências de gates aprovados no ambiente remoto.
- Sem ALB nem health check de ALB. `/ready` cobre conexão SQLite, mas não comprova saúde da rede externa ou restauração de dados.
- SQLite com PVC e uma réplica implica indisponibilidade breve durante `Recreate`; rollback de código não reverte dados.

Estas são diferenças entre **código existente, relações detectadas e operação demonstrada**; não são inferências de que a implantação ocorreu.
