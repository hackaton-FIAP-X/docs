# Bucket Key Layout Specification

## Versão: 1.2
## Compatível com: video-service v1, video-processor v1

---

## Buckets por Ambiente

| Ambiente | Bucket | Região |
|----------|--------|--------|
| **Local (kind / compose)** | **`fiapx`** — prefixos `inputs/` e `outputs/` | — (MinIO) |
| **AWS (Learner Lab)** | `fiapx-app-<conta>-<sufixo>` (criado pelo Terraform), mesmos prefixos | `us-east-1` (S3) — ver [ADR-002](../../adr/ADR-002-alvo-aws-learner-lab.md) |
| Homologação *(não implementado)* | `oficina-videos-homolog` | `us-east-1` |
| Produção *(não implementado)* | `oficina-videos-prod` | `us-east-1` |

---

## ⚠️ Layout implementado (vale sobre o resto deste documento)

Ver [ADR-001](../../adr/ADR-001-stack-local-kind-rabbitmq-minio.md). O fluxo
entregue é **vídeo → frames → `.zip`**, escopado **por usuário**, não o
transcoding multi-perfil por `video_id` descrito nas seções seguintes.

| Item | Valor |
|------|-------|
| Provedor | **MinIO** (API compatível com S3), não AWS S3 |
| Endpoint | `http://minio.fiapx.svc.cluster.local:9000` (via `STORAGE_ENDPOINT`) |
| Console | `http://localhost:9001` (`kubectl -n fiapx port-forward svc/minio 9001:9001`) |
| Credenciais | Secret `app-credentials`: `STORAGE_ACCESS_KEY` / `STORAGE_SECRET_KEY` |
| Bucket | **`fiapx`** — um só, com prefixos (`STORAGE_BUCKET`) |
| Criação | Job `minio-createbuckets` no repo `infra` |

### Chaves

```
fiapx/inputs/{userId}/{videoId}/{originalFilename}    # vídeo original (VID-3)
fiapx/outputs/{userId}/{videoId}.zip                  # ZIP de frames (WRK-4)
```

Fonte de verdade: os comentários de `storage_key` e `zip_key` em
`video-service/src/main/resources/db/migration/V1__criar_tabela_videos.sql`.

Presigned URLs são geradas pelo SDK AWS S3 v2 apontando para o MinIO
(download com TTL de 5 minutos — VID-6). Lifecycle policies (IA/Glacier) não se
aplicam ao MinIO local.

---

> **As seções abaixo são o contrato original da Fase 3** (domínio "oficina",
> AWS S3, transcoding multi-perfil, chaves por `video_id`). Ficam registradas
> como histórico e como referência caso o projeto volte para um provedor
> gerenciado — **não descrevem o que está implementado**.

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