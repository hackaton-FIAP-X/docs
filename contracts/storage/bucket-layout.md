# Bucket Key Layout Specification

## Versão: 1.1
## Compatível com: video-service v1, video-processor v1

---

## Buckets por Ambiente

| Ambiente | Bucket Original | Bucket Processado | Região |
|----------|-----------------|-------------------|--------|
| Local (kind) | `fiapx-videos` | `fiapx-outputs` | — (MinIO) |
| Homologação | `oficina-videos-homolog` | `oficina-videos-homolog` | `us-east-1` |
| Produção | `oficina-videos-prod` | `oficina-videos-prod` | `us-east-1` |

> **Nota**: em homolog/prod, mesmo bucket para original e processado (pastas diferentes).

---

## Local (kind) — ver [ADR-001](../../adr/ADR-001-stack-local-kind-rabbitmq-minio.md)

No ambiente local o object storage é **MinIO** (API compatível com S3), não AWS S3.

| Item | Valor local |
|------|-------------|
| Endpoint | `http://minio.fiapx.svc.cluster.local:9000` (via `MINIO_ENDPOINT`) |
| Console | `http://localhost:9001` (após `kubectl -n fiapx port-forward svc/minio 9001:9001`) |
| Credenciais | Secret `app-credentials`: `MINIO_ACCESS_KEY` / `MINIO_SECRET_KEY` |
| Bucket original | `fiapx-videos` (chaves `uploads/{video_id}/{filename}`, `tmp/{video_id}/...`) |
| Bucket de saída | `fiapx-outputs` (chaves `processed/{video_id}/...`, `thumbnails/{video_id}/...`) |
| Criação dos buckets | Job `minio-createbuckets` (`k8s/infra/base/minio/job-createbuckets.yaml` no repo `infra`) |

O **layout de chaves, regras de naming e TTLs abaixo continuam valendo** — só o
provedor muda. Presigned URLs são geradas pelo SDK AWS S3 v2 apontando para o
endpoint do MinIO. Lifecycle policies (IA/Glacier) não se aplicam ao MinIO local.

---

## Estrutura de Chaves (Object Keys)

### 1. Upload Original (Presigned PUT)

```
uploads/{video_id}/{filename}
```

**Exemplo:**
```
uploads/550e8400-e29b-41d4-a716-446655440000/aula-01.mp4
```

- `video_id`: UUID v4 gerado no `initiateUpload`
- `filename`: Nome original sanitizado (mantém extensão)

---

### 2. Arquivos Processados (Outputs do Processor)

```
processed/{video_id}/{filename}_{profile}.{ext}
```

**Perfis padrão:**
| Profile | Descrição | Exemplo |
|---------|-----------|---------|
| `original` | Cópia do original (pode ser re-encodado) | `aula-01_original.mp4` |
| `1080p` | 1920x1080, ~8 Mbps | `aula-01_1080p.mp4` |
| `720p` | 1280x720, ~5 Mbps | `aula-01_720p.mp4` |
| `480p` | 854x480, ~2.5 Mbps | `aula-01_480p.mp4` |
| `360p` | 640x360, ~1 Mbps | `aula-01_360p.mp4` |

**Exemplos:**
```
processed/550e8400-e29b-41d4-a716-446655440000/aula-01_original.mp4
processed/550e8400-e29b-41d4-a716-446655440000/aula-01_720p.mp4
processed/550e8400-e29b-41d4-a716-446655440000/aula-01_480p.mp4
```

---

### 3. Thumbnails

```
thumbnails/{video_id}/thumb_{sequence:04d}.jpg
```

**Exemplos:**
```
thumbnails/550e8400-e29b-41d4-a716-446655440000/thumb_0001.jpg
thumbnails/550e8400-e29b-41d4-a716-446655440000/thumb_0002.jpg
```

- Gerados a cada ~10% do vídeo (máx 10 thumbnails)
- `sequence`: Número sequencial 1-10

---

### 4. Arquivos Temporários (Processor)

```
tmp/{video_id}/{random}/{filename}
```

**Exemplo:**
```
tmp/550e8400-e29b-41d4-a716-446655440000/abc123/aula-01.mp4
```

- Usados durante processamento (download, transcodificação)
- **TTL**: 24h (regra de lifecycle para limpeza automática)
- `random`: String aleatória para evitar colisão em processamento paralelo

---

## Regras de Naming

| Regra | Descrição |
|-------|-----------|
| Lowercase | Todas as chaves em minúsculo |
| Sanitização | Remover acentos, espaços → `_`, caracteres especiais |
| Extensão | Manter extensão original (`.mp4`, `.mov`, `.avi`, `.mkv`) |
| UUID | Sempre UUID v4 com hífens (`550e8400-e29b-41d4-a716-446655440000`) |

---

## Lifecycle Policies

| Prefixo | Ação | Após |
|---------|------|------|
| `tmp/` | Delete | 1 dia |
| `uploads/` | Transition to IA | 30 dias |
| `uploads/` | Transition to Glacier | 90 dias |
| `processed/` | Transition to IA | 60 dias |
| `thumbnails/` | Transition to IA | 60 dias |

---

## Permissões (IAM)

### video-service (Lambda/ECS)
```json
{
  "Effect": "Allow",
  "Action": [
    "s3:PutObject",
    "s3:GetObject",
    "s3:DeleteObject"
  ],
  "Resource": [
    "arn:aws:s3:::oficina-videos-{env}/uploads/*",
    "arn:aws:s3:::oficina-videos-{env}/tmp/*"
  ]
}
```

### video-processor (ECS/Fargate)
```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject",
    "s3:PutObject",
    "s3:DeleteObject"
  ],
  "Resource": [
    "arn:aws:s3:::oficina-videos-{env}/uploads/*",
    "arn:aws:s3:::oficina-videos-{env}/processed/*",
    "arn:aws:s3:::oficina-videos-{env}/thumbnails/*",
    "arn:aws:s3:::oficina-videos-{env}/tmp/*"
  ]
}
```

### API Gateway / CDN (CloudFront)
```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject"
  ],
  "Resource": [
    "arn:aws:s3:::oficina-videos-{env}/processed/*",
    "arn:aws:s3:::oficina-videos-{env}/thumbnails/*"
  ]
}
```

---

## Presigned URL Configuração

| Operação | Método HTTP | Expiração | Headers Obrigatórios |
|----------|-------------|-----------|---------------------|
| Upload Original | PUT | 1 hora (3600s) | `Content-Type` |
| Download Processado | GET | 1 hora (3600s) | - |
| Thumbnail | GET | 24 horas (86400s) | - |

---

## Eventos de Storage

| Ambiente | Como o `video.uploaded` é gerado | Transporte |
|----------|--------------------------------|------------|
| Local (kind) | **`video-service` publica** o evento após concluir o upload | fila **RabbitMQ** (`video.uploaded`) |
| AWS (homolog/prod) | S3 Event Notification em `s3:ObjectCreated:*` no prefixo `uploads/` | SQS `video-uploaded-queue` |

> `video.processed` / `video.failed` são sempre emitidos pelo `video-processor`
> (nunca pelo storage). Payloads em `../events/*.json`.