# infra-check

Ferramenta demonstrativa, não usada profissionalmente neste repositório.

```sh
go run ./cmd/infra-check health http://localhost:8080
go run ./cmd/infra-check version http://localhost:8080
go run ./cmd/infra-check deployment web-app web-app
go run ./cmd/infra-check rollback web-app web-app
```

`rollback` altera o Deployment Kubernetes; requer contexto kubeconfig e permissão apropriada. Para releases Helm, prefira `helm rollback web-app <revision> -n web-app` para manter o histórico Helm coerente. SQLite não é revertido.
