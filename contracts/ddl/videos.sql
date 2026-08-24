-- Tabela de vídeos (video-service)
-- Versão: 1.0
-- Compatível com: video-service v1

CREATE TABLE videos (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    filename VARCHAR(255) NOT NULL,
    content_type VARCHAR(100) NOT NULL CHECK (content_type IN ('video/mp4', 'video/quicktime', 'video/x-msvideo', 'video/x-matroska')),
    size_bytes BIGINT NOT NULL CHECK (size_bytes > 0 AND size_bytes <= 5368709120),
    status VARCHAR(20) NOT NULL DEFAULT 'UPLOADED' CHECK (status IN ('UPLOADED', 'PROCESSING', 'PROCESSED', 'FAILED')),
    duration_seconds INTEGER,
    width INTEGER,
    height INTEGER,
    bitrate_kbps INTEGER,
    codec VARCHAR(50),
    thumbnail_url VARCHAR(500),
    bucket VARCHAR(100) NOT NULL,
    object_key VARCHAR(500) NOT NULL,
    checksum_sha256 CHAR(64),
    error_code VARCHAR(50),
    error_message TEXT,
    retry_count INTEGER NOT NULL DEFAULT 0,
    max_retries INTEGER NOT NULL DEFAULT 3,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP,
    
    CONSTRAINT fk_videos_user FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Índices
CREATE INDEX idx_videos_user_id ON videos(user_id);
CREATE INDEX idx_videos_status ON videos(status);
CREATE INDEX idx_videos_created_at ON videos(created_at DESC);
CREATE INDEX idx_videos_user_status ON videos(user_id, status);

-- Tabela de outputs de processamento (transcodings, thumbnails)
CREATE TABLE video_outputs (
    id UUID PRIMARY KEY,
    video_id UUID NOT NULL,
    profile VARCHAR(50) NOT NULL,
    bucket VARCHAR(100) NOT NULL,
    object_key VARCHAR(500) NOT NULL,
    size_bytes BIGINT NOT NULL,
    width INTEGER,
    height INTEGER,
    content_type VARCHAR(100) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_video_outputs_video FOREIGN KEY (video_id) REFERENCES videos(id) ON DELETE CASCADE,
    CONSTRAINT uk_video_outputs_profile UNIQUE (video_id, profile)
);

CREATE INDEX idx_video_outputs_video_id ON video_outputs(video_id);

-- Comentários
COMMENT ON TABLE videos IS 'Metadados de vídeos enviados para processamento';
COMMENT ON COLUMN videos.id IS 'Identificador único do vídeo (UUID v4)';
COMMENT ON COLUMN videos.user_id IS 'Referência ao usuário dono do vídeo';
COMMENT ON COLUMN videos.filename IS 'Nome original do arquivo';
COMMENT ON COLUMN videos.content_type IS 'MIME type do vídeo original';
COMMENT ON COLUMN videos.size_bytes IS 'Tamanho em bytes (máx 5GB)';
COMMENT ON COLUMN videos.status IS 'Estado do processamento';
COMMENT ON COLUMN videos.duration_seconds IS 'Duração em segundos (preenchido após processado)';
COMMENT ON COLUMN videos.width IS 'Largura em pixels';
COMMENT ON COLUMN videos.height IS 'Altura em pixels';
COMMENT ON COLUMN videos.bitrate_kbps IS 'Bitrate em kbps';
COMMENT ON COLUMN videos.codec IS 'Codec de vídeo (ex: h264, h265, vp9)';
COMMENT ON COLUMN videos.thumbnail_url IS 'URL pública do thumbnail';
COMMENT ON COLUMN videos.bucket IS 'Bucket S3 onde o arquivo original está';
COMMENT ON COLUMN videos.object_key IS 'Chave do objeto no bucket';
COMMENT ON COLUMN videos.checksum_sha256 IS 'SHA-256 do arquivo original para verificação de integridade';
COMMENT ON COLUMN videos.error_code IS 'Código de erro padronizado (ex: PROCESSING_TIMEOUT, INVALID_FORMAT)';
COMMENT ON COLUMN videos.error_message IS 'Mensagem de erro detalhada';
COMMENT ON COLUMN videos.retry_count IS 'Número de tentativas de reprocessamento';
COMMENT ON COLUMN videos.max_retries IS 'Máximo de tentativas permitidas';
COMMENT ON COLUMN videos.created_at IS 'Data de criação do registro (upload iniciado)';
COMMENT ON COLUMN videos.updated_at IS 'Data da última atualização de status';
COMMENT ON COLUMN videos.processed_at IS 'Data de conclusão do processamento (sucesso ou falha final)';

COMMENT ON TABLE video_outputs IS 'Arquivos gerados durante o processamento (transcodings, thumbnails)';
COMMENT ON COLUMN video_outputs.profile IS 'Perfil de saída: original, 1080p, 720p, 480p, 360p, thumbnail';
COMMENT ON COLUMN video_outputs.content_type IS 'MIME type do arquivo de saída';