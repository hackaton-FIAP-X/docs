# Arquitetura — FIAP X (DOC-1)

Sistema que recebe vídeos, extrai os frames e devolve um `.zip`, com processamento
assíncrono, escala horizontal e nenhuma requisição aceita perdida.

- Decisões: [ADR-001](../adr/ADR-001-stack-local-kind-rabbitmq-minio.md) (stack local) e
  [ADR-002](../adr/ADR-002-alvo-aws-learner-lab.md) (AWS).
- Banco: [`database/schema.sql`](../database/schema.sql).
- Subir o ambiente: repo `infra` (`make up` local, `scripts/aws-up.sh` na AWS).

---

## C4 — Contexto

```mermaid
C4Context
  title FIAP X — Contexto
  Person(user, "Usuário", "Envia vídeos e baixa o ZIP de frames")
  System(fiapx, "FIAP X", "Processamento de vídeos em frames")
  System_Ext(mail, "E-mail (SMTP)", "Aviso de falha no processamento")
  Rel(user, fiapx, "Cadastro, login, upload, status, download", "HTTPS/JSON")
  Rel(fiapx, mail, "Notifica falha", "SMTP")
```

## C4 — Containers

```mermaid
C4Container
  title FIAP X — Containers
  Person(user, "Usuário")

  System_Boundary(k8s, "Kubernetes (kind local / EKS na AWS)") {
    Container(ingress, "Ingress NGINX", "NLB na AWS", "Roteia /auth e /videos")
    Container(auth, "auth-service", "Spring Boot 3.3 / Java 21", "Cadastro, login, JWT RS256, JWKS, rate limit")
    Container(video, "video-service", "Spring Boot 3.3 / Java 21", "Upload, listagem, status, download; outbox")
    Container(worker, "video-processor", "Spring Boot 3.3 + FFmpeg", "Frames -> ZIP; HPA 2-10 réplicas")
    Container(obs, "Prometheus + Grafana", "", "Fila, réplicas, throughput, latência")
  }

  ContainerDb(pg, "PostgreSQL", "RDS na AWS", "authdb (users), videodb (videos, outbox_events)")
  ContainerQueue(mq, "RabbitMQ", "Amazon MQ na AWS", "exchange fiapx.video; filas video.processing e video.status; DLQs")
  ContainerDb(redis, "Redis", "ElastiCache na AWS", "Cache da listagem, contador do rate limit")
  ContainerDb(s3, "Object storage", "S3 na AWS / MinIO local", "fiapx/inputs e fiapx/outputs")

  Rel(user, ingress, "HTTPS")
  Rel(ingress, auth, "/auth, /.well-known/jwks.json")
  Rel(ingress, video, "/videos")
  Rel(video, auth, "Busca a JWKS (valida o token offline)")
  Rel(auth, pg, "users")
  Rel(auth, redis, "rate limit do login")
  Rel(video, pg, "videos + outbox")
  Rel(video, redis, "cache da listagem")
  Rel(video, s3, "grava o vídeo; URL pré-assinada do ZIP")
  Rel(video, mq, "publica video.uploaded; consome video.status")
  Rel(worker, mq, "consome video.processing; publica processed/failed")
  Rel(worker, s3, "baixa o vídeo; sobe o ZIP")
  Rel(obs, worker, "raspa /actuator/prometheus")
```

---

## Fluxo de um vídeo

```mermaid
sequenceDiagram
  autonumber
  actor U as Usuário
  participant A as auth-service
  participant V as video-service
  participant DB as Postgres (videodb)
  participant S3 as Object storage
  participant MQ as RabbitMQ
  participant W as video-processor

  U->>A: POST /auth/login
  A-->>U: JWT (RS256)
  U->>V: POST /videos (multipart, Bearer)
  V->>S3: grava fiapx/inputs/{user}/{video}/arquivo (streaming)
  V->>DB: video RECEIVED + evento no outbox (mesma transação)
  V-->>U: 202 {videoId}
  V->>MQ: outbox publica video.uploaded (publisher confirm)
  Note over V,DB: status QUEUED
  MQ->>W: video.processing (prefetch 1, ack manual)
  W->>S3: baixa o vídeo
  W->>W: ffmpeg -vf fps=1 -> frames -> ZIP em streaming
  W->>S3: grava fiapx/outputs/{user}/{video}.zip
  W->>MQ: video.processed (publisher confirm)
  W-->>MQ: ack
  MQ->>V: video.status
  V->>DB: COMPLETED, frameCount, zipKey
  U->>V: GET /videos/{id}/zip
  V-->>U: 302 URL pré-assinada (5 min)
  U->>S3: baixa o ZIP
```

## Estados de um vídeo

```mermaid
stateDiagram-v2
  [*] --> RECEIVED: upload aceito (202)
  RECEIVED --> QUEUED: outbox publicou video.uploaded
  QUEUED --> COMPLETED: video.processed
  QUEUED --> FAILED: video.failed
  RECEIVED --> FAILED
  COMPLETED --> [*]
  FAILED --> [*]
```

---

## Requisitos do enunciado → como são atendidos

| Requisito | Como |
|---|---|
| Processar mais de um vídeo ao mesmo tempo | Worker desacoplado por fila; HPA de 2 a 10 réplicas, `prefetch=1` distribui a carga |
| Não perder requisição em pico | Upload grava vídeo + evento na mesma transação (outbox); publisher confirms; ack manual só depois do resultado confirmado; DLQ. Teste k6: 50 uploads simultâneos, 0 perdidos |
| Protegido por usuário e senha | auth-service: Argon2id + pepper, JWT RS256, rate limit de login no Redis |
| Listagem de status por usuário | `GET /videos` paginado e escopado ao `sub` do token (vídeo de outro usuário → 404) |
| Notificação em caso de erro | Evento `video.failed` → e-mail (Mailhog local) — **PLT-8 em andamento** |
| Persistir os dados | PostgreSQL (RDS na AWS), migrations Flyway |
| Arquitetura escalável | Kubernetes, HPA, serviços stateless, fila entre upload e processamento |
| Testes | JUnit + Testcontainers nos 3 serviços, gate JaCoCo; E2E no `verify.sh`; carga com k6 |
| CI/CD | GitHub Actions: CI por repo; CD com build, kind efêmero e smoke test; Terraform validado no Floci |
