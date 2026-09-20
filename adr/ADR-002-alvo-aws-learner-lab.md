# Título

**ADR-002**: Alvo de produção na AWS (Learner Lab) com Terraform — EKS e serviços gerenciados

---

## Status

- [ ] Proposto
- [x] Aceito
- [ ] Depreciado
- [ ] Substituído por ADR-XXX

---

## Contexto

A [ADR-001](ADR-001-stack-local-kind-rabbitmq-minio.md) definiu a stack de
desenvolvimento e demo local: kind, RabbitMQ, MinIO, PostgreSQL e Redis, tudo
dentro do cluster. O time decidiu que o ambiente de entrega roda **na AWS**,
provisionado com **Terraform**.

A conta disponível é a do **AWS Academy Learner Lab**, com restrições que moldam
a solução:

- não é possível criar IAM (roles, políticas, OIDC); existe um papel pronto, o
  `LabRole`;
- credenciais temporárias por sessão (≈4h), com session token;
- crédito limitado, regiões us-east-1 e us-west-2;
- sem OIDC, o GitHub Actions não assume papel na conta.

---

## Decisão

| Capacidade | Local (ADR-001) | AWS (esta ADR) |
|---|---|---|
| Orquestração | kind | **EKS 1.31**, node group t3.large (2 a 4 nós) |
| Registry | imagens `:local` | **ECR** |
| Banco | Postgres no cluster | **RDS PostgreSQL 16** (`authdb`, `videodb`) |
| Mensageria | RabbitMQ no cluster | **RabbitMQ no EKS** (StatefulSet, disco efêmero) — Amazon MQ negado pelo lab |
| Cache | Redis no cluster | **ElastiCache Redis 7** |
| Object storage | MinIO | **S3** (bucket criado pela CLI, não pelo Terraform) |
| Rede | — | VPC em 2 AZs, subnets privadas, 1 NAT |
| IaC | manifests + Kustomize | **Terraform** (`infra/terraform`), estado remoto em S3 |

- **RabbitMQ em vez de SQS:** video-service e video-processor não mudam uma
  linha (exchange topic, quorum queues, DLX, publisher confirms). SQS exigiria
  reescrever o outbox, o consumer de status e a DLQ.
- **RabbitMQ no EKS, não no Amazon MQ (revisão 1.1):** o primeiro `apply` no
  Learner Lab recebeu `AccessDenied` em `mq:CreateBroker`. Aplicado o plano B: o
  mesmo StatefulSet da ADR-001.
- **Disco efêmero para o RabbitMQ (revisão 1.2):** o volume EBS foi tentado e
  abandonado. Um disco EBS vive numa única AZ e prende o pod a um nó, que ficou
  sem CPU (`Insufficient cpu` + `volume node affinity conflict`); e o `fsGroup`
  aplicado ao volume devolvia permissão de grupo ao cookie do Erlang, que o
  RabbitMQ recusa. Com `emptyDir`, **mensagem ainda em fila se perde se o pod
  reiniciar**. O que já foi aceito não se perde: o video-service grava no banco
  (outbox) antes de publicar e o video-processor só confirma a mensagem depois
  de gravar o ZIP no S3. O driver EBS e a StorageClass gp3 continuam instalados,
  caso se queira voltar a persistir.
- **Bucket da aplicação fora do Terraform (revisão 1.1):** o `aws_s3_bucket` do
  provider AWS sempre lê a configuração de object lock, e um SCP do lab nega
  `s3:GetBucketObjectLockConfiguration`. O bucket `fiapx-app-<conta>-<região>` é
  criado e apagado pela CLI (`infra/scripts/aws-lib.sh`), como o bucket do estado.
- **IAM:** cluster e nós usam o `LabRole`. Os pods acessam o S3 com as
  credenciais do nó pela cadeia padrão da AWS (IMDSv2, hop limit 2); não há
  chave fixa em lugar nenhum.
- **Ciclo de vida:** o ambiente **sobe para a demo e é destruído**
  (`infra/scripts/aws-up.sh` e `aws-down.sh`).
- **Teste sem AWS:** o Terraform é validado a cada PR contra o **Floci**,
  emulador AWS local gratuito (apply + destroy completos).

---

## Consequências

### Positivas
- ✅ Serviços gerenciados para banco, fila e cache: persistência e operação sem
  StatefulSets.
- ✅ Nenhuma mudança de código por causa da mensageria.
- ✅ Kubernetes igual ao local: manifests, HPA, Prometheus/Grafana, `verify.sh`
  e k6 são os mesmos.
- ✅ Terraform testado sem gastar crédito (Floci na CI).

### Negativas / Riscos
- ❌ Sem OIDC, o deploy na AWS é manual (credenciais da sessão), não automático
  a cada merge. O CD automático continua validando no kind efêmero.
- ❌ EKS + NAT + RDS + ElastiCache custam por hora: esquecer o ambiente ligado
  consome o crédito do lab.
- ❌ O RabbitMQ no cluster é mais um componente para operar (1 réplica, sem
  cluster RabbitMQ) e, com disco efêmero, um restart do pod descarta a fila.
  Aceitável para a demo; num ambiente real seria EFS (multi-AZ), um cluster
  RabbitMQ com réplicas, ou o Amazon MQ numa conta sem as restrições do lab.

### Neutras / Trade-offs
- ⚖️ Single-AZ para RDS, RabbitMQ e ElastiCache: suficiente para a demo, sem
  alta disponibilidade.
- ⚖️ Um NAT só: metade do custo, com um ponto único de falha na saída para a
  internet.

---

## Alternativas Avaliadas

| Alternativa | Prós | Contras | Por que não |
|---|---|---|---|
| ECS Fargate | Sem cluster para operar | Reescreve deploy, autoscaling e observabilidade | Perde tudo que já roda no Kubernetes |
| SQS (+ SNS) | Nativo, barato | Reescreve a mensageria dos dois serviços | Custo alto de mudança no fim do projeto |
| Tudo dentro do EKS | Mais barato | Persistência em volumes do cluster | O enunciado pede persistência; gerenciado é mais defensável |
| LocalStack para testar | Popular | Community edition exige token desde 2026 | Floci é gratuito e atende os serviços usados |

---

## Plano de Implementação

1. [x] `terraform/bootstrap`: bucket do estado remoto.
2. [x] `terraform/aws`: VPC, EKS (+ EBS CSI), ECR, RDS, ElastiCache; RabbitMQ no EKS e bucket S3 pela CLI (revisão 1.1).
3. [x] Overlays `k8s/*/overlays/aws` + `scripts/aws-render.sh`.
4. [x] `scripts/aws-up.sh` e `scripts/aws-down.sh`.
5. [x] CI do Terraform com Floci.
6. [x] video-processor: credenciais pela cadeia padrão e AMQPS opcional.
7. [ ] video-service: credenciais pela cadeia padrão e endpoint opcional (PR aberto).
8. [ ] Primeiro `aws-up.sh` numa sessão do Learner Lab e `verify.sh` verde no EKS.

---

## Métricas de Sucesso

- `aws-up.sh` sobe tudo e o `verify.sh` (com E2E) passa no EKS.
- `make load WAIT=true` contra o NLB: processados = enviados.
- `aws-down.sh` não deixa recurso órfão.

---

## Referências

- `infra/README.md` — seção "Subir na AWS".
- [Floci](https://github.com/floci-io/floci)
- [Amazon MQ for RabbitMQ](https://docs.aws.amazon.com/amazon-mq/latest/developer-guide/working-with-rabbitmq.html)

---

## Metadados

| Campo | Valor |
|---|---|
| Autor | @denisrodrigues |
| Data | 2026-09-19 |
| Revisores | time FIAP X |
| Próxima revisão | 2027-03-19 (6 meses) |

---

## Changelog

| Data | Versão | Autor | Mudança |
|---|---|---|---|
| 2026-09-19 | 1.0 | @denisrodrigues | Criação: alvo AWS (EKS + serviços gerenciados), restrições do Learner Lab |
| 2026-09-19 | 1.1 | @denisrodrigues | Plano B aplicado: RabbitMQ no EKS (Amazon MQ negado) e bucket S3 pela CLI (SCP nega leitura de object lock) |
| 2026-09-20 | 1.2 | @denisrodrigues | RabbitMQ passa a disco efêmero: EBS prende o pod a uma AZ e quebra a permissão do cookie do Erlang |
