# Bucket Key Layout Specification

## Versão: 1.0
## Compatível com: video-service v1, video-processor v1

---

## Buckets por Ambiente

| Ambiente | Bucket Original | Bucket Processado | Região |
|----------|-----------------|-------------------|--------|
| Homologação | `oficina-videos-homolog` | `oficina-videos-homolog` | `us-east-1` |
| Produção | `oficina-videos-prod` | `oficina-videos-prod` | `us-east-1` |

> **Nota**: Mesmo bucket para original e processado, pastas diferentes.

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

## Eventos de Storage (S3 Event Notifications)

| Evento | Prefixo | Destino |
|--------|---------|---------|
| `s3:ObjectCreated:*` | `uploads/` | SQS `video-uploaded-queue` |
| `s3:ObjectCreated:*` | `processed/` | SQS `video-processed-queue` (opcional) |

> O `video-processed` event é emitido pelo processor, não pelo S3.