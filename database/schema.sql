-- =============================================================================
-- FIAP X - Sistema de Processamento de Videos
-- Script consolidado de criacao do banco de dados  (PLT-9)
--
-- Entregavel obrigatorio do enunciado: "Script de criacao do banco de dados ou
-- de outros recursos utilizados."
--
-- Fonte: docs/contracts/ddl/users.sql + docs/contracts/ddl/videos.sql
-- Substrato: PostgreSQL 16 (ver docs/adr/ADR-001-stack-local-kind-rabbitmq-minio.md)
--
-- COMO RODAR (base vazia):
--     psql -U <user> -h <host> -f docs/database/schema.sql
--
-- No cluster kind, os dois databases ja sao criados pelo initdb do Postgres
-- (infra/k8s/infra/base/postgres/configmap.yaml). Rodando este script inteiro
-- em uma instancia limpa, os CREATE DATABASE abaixo cuidam disso.
--
-- NOTA SOBRE FLYWAY: quando AUTH-1 e VID-1 introduzirem as migrations Flyway,
-- este arquivo deve ser regerado a partir delas para nao divergir.
-- =============================================================================


-- =============================================================================
-- DATABASES  (um por servico)
-- =============================================================================
-- Comente estas duas linhas se os databases ja existirem (caso do kind).
CREATE DATABASE authdb;
CREATE DATABASE videodb;


-- =============================================================================
-- 1) authdb  -  auth-service
-- =============================================================================
\connect authdb

CREATE TABLE users (
    id UUID PRIMARY KEY,
    nome VARCHAR(200) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    senha VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL CHECK (role IN ('ADMIN', 'GERENTE', 'MECANICO', 'ATENDENTE', 'CLIENTE')),
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    data_cadastro TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao TIMESTAMP
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_ativo ON users(ativo);

COMMENT ON TABLE users IS 'Usuarios do sistema (internos e clientes)';
COMMENT ON COLUMN users.id IS 'Identificador unico (UUID v4)';
COMMENT ON COLUMN users.nome IS 'Nome completo do usuario';
COMMENT ON COLUMN users.email IS 'Email unico, usado como login';
COMMENT ON COLUMN users.senha IS 'Hash bcrypt da senha';
COMMENT ON COLUMN users.role IS 'Perfil de acesso: ADMIN, GERENTE, MECANICO, ATENDENTE, CLIENTE';
COMMENT ON COLUMN users.ativo IS 'Se o usuario pode autenticar';
COMMENT ON COLUMN users.data_cadastro IS 'Data de criacao do registro';
COMMENT ON COLUMN users.data_atualizacao IS 'Data da ultima atualizacao';


-- =============================================================================
-- 2) videodb  -  video-service / video-processor
-- =============================================================================
\connect videodb

-- ATENCAO - divergencia deliberada em relacao a docs/contracts/ddl/videos.sql:
-- o contrato declara  CONSTRAINT fk_videos_user FOREIGN KEY (user_id)
-- REFERENCES users(id).  Isso e impossivel aqui porque `users` vive em outro
-- database (authdb) e o PostgreSQL nao suporta foreign key entre databases.
-- Manter `user_id` como UUID sem FK e o comportamento correto para uma
-- fronteira de microsservico: a integridade referencial entre servicos e
-- garantida pelo token (claim `sub`) e pelos eventos, nao pelo banco.
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
    processed_at TIMESTAMP
);

CREATE INDEX idx_videos_user_id ON videos(user_id);
CREATE INDEX idx_videos_status ON videos(status);
CREATE INDEX idx_videos_created_at ON videos(created_at DESC);
CREATE INDEX idx_videos_user_status ON videos(user_id, status);

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

COMMENT ON TABLE videos IS 'Metadados de videos enviados para processamento';
COMMENT ON COLUMN videos.id IS 'Identificador unico do video (UUID v4)';
COMMENT ON COLUMN videos.user_id IS 'Usuario dono do video (claim sub do JWT, sem FK - outro database)';
COMMENT ON COLUMN videos.filename IS 'Nome original do arquivo';
COMMENT ON COLUMN videos.content_type IS 'MIME type do video original';
COMMENT ON COLUMN videos.size_bytes IS 'Tamanho em bytes (max 5GB)';
COMMENT ON COLUMN videos.status IS 'Estado do processamento: UPLOADED -> PROCESSING -> PROCESSED | FAILED';
COMMENT ON COLUMN videos.duration_seconds IS 'Duracao em segundos (preenchido apos processado)';
COMMENT ON COLUMN videos.width IS 'Largura em pixels';
COMMENT ON COLUMN videos.height IS 'Altura em pixels';
COMMENT ON COLUMN videos.bitrate_kbps IS 'Bitrate em kbps';
COMMENT ON COLUMN videos.codec IS 'Codec de video (ex: h264, h265, vp9)';
COMMENT ON COLUMN videos.thumbnail_url IS 'URL publica do thumbnail';
COMMENT ON COLUMN videos.bucket IS 'Bucket (MinIO no local) onde o arquivo original esta';
COMMENT ON COLUMN videos.object_key IS 'Chave do objeto no bucket';
COMMENT ON COLUMN videos.checksum_sha256 IS 'SHA-256 do arquivo original para verificacao de integridade';
COMMENT ON COLUMN videos.error_code IS 'Codigo de erro padronizado (ex: PROCESSING_TIMEOUT, INVALID_FORMAT)';
COMMENT ON COLUMN videos.error_message IS 'Mensagem de erro detalhada';
COMMENT ON COLUMN videos.retry_count IS 'Numero de tentativas de reprocessamento';
COMMENT ON COLUMN videos.max_retries IS 'Maximo de tentativas permitidas';
COMMENT ON COLUMN videos.created_at IS 'Data de criacao do registro (upload iniciado)';
COMMENT ON COLUMN videos.updated_at IS 'Data da ultima atualizacao de status';
COMMENT ON COLUMN videos.processed_at IS 'Data de conclusao do processamento (sucesso ou falha final)';

COMMENT ON TABLE video_outputs IS 'Artefatos gerados no processamento. No fluxo do hackathon (frames -> zip) o profile e "zip", e o modelo tambem suporta transcodings/thumbnails.';
COMMENT ON COLUMN video_outputs.profile IS 'Perfil de saida: zip (frames), original, 1080p, 720p, 480p, 360p, thumbnail';
COMMENT ON COLUMN video_outputs.content_type IS 'MIME type do arquivo de saida';
