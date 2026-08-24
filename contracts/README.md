# Contratos de Integração — Tech Challenge Fase 3

## Visão Geral

Este diretório contém os contratos congelados que permitem as **4 trilhas rodarem em paralelo**:

| Trilha | Repositório | Contratos Consumidos |
|--------|-------------|---------------------|
| 1. Auth Lambda | `auth-lambda` | `openapi/auth-service-v1.yaml`, `jwt/claims.md`, `ddl/users.sql` |
| 2. Infra K8s | `infra-k8s-terraform` | `openapi/*.yaml` (para API Gateway routes) |
| 3. Infra DB | `infra-db-terraform` | `ddl/users.sql`, `ddl/videos.sql` |
| 4. App Principal | `app-main-k8s` | `openapi/video-service-v1.yaml`, `events/*.json`, `jwt/claims.md`, `storage/bucket-layout.md` |

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
2. **Discutir**: Alinhar impacto nas 4 trilhas (breaking vs non-breaking)
3. **Implementar**: Atualizar arquivos em `docs/contracts/` + código afetado
4. **PR único**: Mesmo PR deve conter:
   - Mudança no contrato (`docs/contracts/...`)
   - Mudança no consumidor (ex: `auth-lambda`, `video-service`, etc.)
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
          # auth-lambda valida auth-service-v1.yaml
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

## Como Usar nas Trilhas

### Auth Lambda (`auth-lambda`)
```bash
# Gerar cliente a partir do OpenAPI
swagger-codegen generate -i docs/contracts/openapi/auth-service-v1.yaml -l kotlin-spring -o src/main/kotlin
# Implementar handler POST /token seguindo TokenRequest/TokenResponse
# Emitir JWT com claims de docs/contracts/jwt/claims.md
```

### Video Service (`app-main-k8s` → video module)
```bash
# Gerar interfaces Spring
swagger-codegen generate -i docs/contracts/openapi/video-service-v1.yaml -l spring-mvc -o src/main/java
# Implementar VideoController
# Publicar eventos Kafka/RabbitMQ seguindo docs/contracts/events/*.json
# Usar docs/contracts/storage/bucket-layout.md para presigned URLs e caminhos
```

### Infra DB (`infra-db-terraform`)
```hcl
# Aplicar migrations baseadas em docs/contracts/ddl/*.sql
resource "aws_db_instance" "main" {
  # ...
}

# Flyway/Liquibase usa os .sql como baseline
```

### Infra K8s (`infra-k8s-terraform`)
```hcl
# API Gateway routes baseados nos paths do OpenAPI
resource "aws_apigatewayv2_route" "auth_token" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /auth/token"
  target    = "integrations/${aws_apigatewayv2_integration.auth_lambda.id}"
}
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

---

**Última atualização**: 2026-08-24  
**Status**: 🟢 **CONGELADO** — Pronto para desenvolvimento paralelo das 4 trilhas