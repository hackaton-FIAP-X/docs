# Contratos de Integração — FIAP X (Hackathon Fase 5)

## Visão Geral

Este diretório contém os contratos congelados que permitem os serviços evoluírem em paralelo.

> **Substrato**: estes contratos foram escritos na Fase 3 assumindo AWS (S3, SQS,
> API Gateway, Lambda). Para o alvo local/hackathon vale a **[ADR-001](../adr/ADR-001-stack-local-kind-rabbitmq-minio.md)**:
> **kind + RabbitMQ + MinIO + PostgreSQL + Redis**. Os *schemas* (evento, DDL,
> claims, layout de chaves) continuam valendo; onde se lê "S3" leia "MinIO" e
> onde se lê "SQS `video-*-queue`" leia "fila RabbitMQ".

| Repositório | Papel | Contratos Consumidos |
|-------------|-------|---------------------|
| `auth-service` | Autenticação, emissão de JWT | `openapi/auth-service-v1.yaml`, `jwt/claims.md`, `ddl/users.sql` |
| `video-service` | Upload, metadados, status, publicação de eventos | `openapi/video-service-v1.yaml`, `events/*.json`, `jwt/claims.md`, `storage/bucket-layout.md` |
| `video-processor` | Worker de processamento (frames → `.zip`), consumo/publicação de eventos | `events/*.json`, `storage/bucket-layout.md` |
| `infra` | Cluster kind, manifests K8s, infra de apoio | `openapi/*.yaml`, `ddl/*.sql` |

---

## Estrutura

```
docs/contracts/
├── openapi/
│   ├── auth-service-v1.yaml      # Auth Lambda (CPF → JWT)
│   └── video-service-v1.yaml     # Video Service (CRUD + presigned URLs)
├── events/
│   ├── video.uploaded.json       # Emitido ao finalizar upload
│   ├── video.processed.json      # Emitido ao concluir processamento
│   └── video.failed.json         # Emitido em falha de processamento
├── ddl/
│   ├── users.sql                 # Tabela users (auth + app)
│   └── videos.sql                # Tabelas videos + video_outputs
├── jwt/
│   └── claims.md                 # Claims do JWT (sub, email, name, iss, exp + custom)
└── storage/
    └── bucket-layout.md          # Layout de chaves S3, lifecycle, IAM
```

---

## Regra do Time (Congelamento)

> **Depois de congelado, mudança de contrato só com aviso no grupo e atualização do `docs/contracts` no mesmo PR.**

### Fluxo de Mudança

1. **Propor mudança**: Abrir issue/discord com `[CONTRACT CHANGE]` no título
2. **Discutir**: Alinhar impacto nos serviços (breaking vs non-breaking)
3. **Implementar**: Atualizar arquivos em `docs/contracts/` + código afetado
4. **PR único**: Mesmo PR deve conter:
   - Mudança no contrato (`docs/contracts/...`)
   - Mudança no consumidor (ex: `auth-service`, `video-service`, `video-processor`)
   - Testes de contrato atualizados
5. **Aprovação**: Mínimo 2 aprovações (incluindo tech lead da trilha impactada)
6. **Deploy**: Merge → CI roda validação de contrato → Deploy coordenado

### Versionamento

- **Major** (v1 → v2): Breaking changes — nova versão do OpenAPI, novo event type
- **Minor** (v1.0 → v1.1): Aditivos — novos campos opcionais, novos endpoints
- **Patch** (v1.0.0 → v1.0.1): Correções — typos, exemplos, documentação

> **Regra**: Nunca remover campos. Marcar como `deprecated: true` no OpenAPI e manter no evento por 2 versões minor.

---

## Validação de Contrato (CI)

Cada repositório deve ter job de validação:

```yaml
# Exemplo: .github/workflows/contract-validation.yml
jobs:
  contract-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Validate OpenAPI
        run: |
          # auth-service valida auth-service-v1.yaml
          # video-service valida video-service-v1.yaml
          swagger-codegen validate -i docs/contracts/openapi/auth-service-v1.yaml
      - name: Validate Events Schema
        run: |
          # Validar JSONs contra schema (ajv, jsonschema, etc.)
          ajv validate -s events/video.uploaded.schema.json -d events/video.uploaded.json
      - name: Validate DDL
        run: |
          # pg_dump --schema-only | diff com ddl/*.sql
          pg_dump --schema-only $DATABASE_URL | grep -E "CREATE TABLE|CREATE INDEX" | diff - ddl/users.sql
```

---

## Como Usar nos Serviços

Stack real: Spring Boot 3.3 / Java 21 / Maven. Ver [ADR-001](../adr/ADR-001-stack-local-kind-rabbitmq-minio.md).

### `auth-service`
```
# Implementar POST /token seguindo TokenRequest / TokenResponse (openapi/auth-service-v1.yaml)
# Emitir JWT com os claims de jwt/claims.md (assinatura HMAC via JWT_SECRET)
# Tabela users conforme ddl/users.sql
```

### `video-service`
```
# Implementar os endpoints de video-service-v1.yaml (upload, listagem, status)
# Publicar video.uploaded no RabbitMQ seguindo events/video.uploaded.json
# Consumir video.processed / video.failed
# Usar storage/bucket-layout.md para as chaves no MinIO (uploads/{video_id}/...)
```

### `video-processor`
```
# Consumir video.uploaded; baixar do MinIO; extrair frames (FFmpeg -vf fps=1); empacotar .zip
# Publicar video.processed / video.failed seguindo events/*.json
```

### `infra`
```
# DDL de ddl/*.sql vira migration Flyway em cada serviço
# Manifests K8s (namespace fiapx) + cluster kind — ver o repo infra/
```

---

## Contatos

| Contrato | Owner | Canal |
|----------|-------|-------|
| auth-service | @auth-team | #auth-contracts |
| video-service | @video-team | #video-contracts |
| events | @platform-team | #platform-events |
| ddl | @db-team | #db-schema |
| jwt | @security-team | #security-jwt |
| storage | @platform-team | #platform-storage |

---

## Histórico de Versões

| Versão | Data | Autor | Mudança |
|--------|------|-------|---------|
| 1.0.0 | 2026-08-24 | @author | Criação inicial (congelamento Fase 3) |
| 1.1.0 | 2026-09-01 | @denisrodrigues | Substrato local (ADR-001): AWS S3/SQS → MinIO/RabbitMQ; mapa de repositórios atualizado |

---

**Última atualização**: 2026-09-01  
**Status**: 🟢 **CONGELADO** (schemas) — substrato local por [ADR-001](../adr/ADR-001-stack-local-kind-rabbitmq-minio.md)