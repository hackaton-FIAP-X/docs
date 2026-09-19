-- =============================================================================
-- FIAP X - Sistema de Processamento de Videos
-- Script consolidado de criacao do banco de dados  (PLT-9)
--
-- ARQUIVO GERADO — nao edite a mao.
-- Regerar:  ./docs/database/generate-schema.sh
-- Fonte de verdade: as migrations Flyway de cada servico.
--
-- Gerado a partir de:
--   auth-service/src/main/resources/db/migration/V1__create_users_table.sql
--   video-service/src/main/resources/db/migration/V1__criar_tabela_videos.sql
--   video-service/src/main/resources/db/migration/V2__criar_tabela_outbox_events.sql
--
-- Substrato: PostgreSQL 16 (docs/adr/ADR-001-stack-local-kind-rabbitmq-minio.md)
--
-- COMO RODAR (instancia limpa):
--   psql -v ON_ERROR_STOP=1 -U <user> -h <host> -d postgres -f docs/database/schema.sql
-- =============================================================================


-- =============================================================================
-- DATABASES (um por servico, sem foreign key entre eles)
-- =============================================================================
-- Comente as duas linhas se os databases ja existirem (caso do cluster kind,
-- onde o initdb do Postgres ja os cria).
CREATE DATABASE authdb;
CREATE DATABASE videodb;


-- =============================================================================
-- 1) authdb  -  auth-service
-- =============================================================================
\connect authdb

-- ---- V1__create_users_table.sql ----
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uk_users_email UNIQUE (email)
);

-- =============================================================================
-- 2) videodb  -  video-service / video-processor
--
-- `videos.user_id` guarda o claim `sub` do JWT e NAO tem foreign key para
-- users: a tabela vive em outro database e o PostgreSQL nao faz FK entre
-- bases. Numa fronteira de microsservico a integridade vem do token e dos
-- eventos, nao do banco.
-- =============================================================================
\connect videodb

-- ---- V1__criar_tabela_videos.sql ----
CREATE TABLE videos (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    original_filename VARCHAR(255) NOT NULL,
    storage_key VARCHAR(512) NOT NULL,
    zip_key VARCHAR(512),
    status VARCHAR(20) NOT NULL,
    frame_count INTEGER,
    error_message VARCHAR(1000),
    attempts INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    CONSTRAINT chk_videos_status CHECK (
        status IN ('RECEIVED', 'QUEUED', 'PROCESSING', 'COMPLETED', 'FAILED')
    ),
    CONSTRAINT chk_videos_frame_count CHECK (frame_count IS NULL OR frame_count >= 0),
    CONSTRAINT chk_videos_attempts CHECK (attempts >= 0)
);

CREATE INDEX idx_videos_user_status_created ON videos (user_id, status, created_at DESC);

CREATE INDEX idx_videos_user_created ON videos (user_id, created_at DESC);

COMMENT ON TABLE videos IS 'Videos enviados pelos usuarios e o estado do seu processamento';
COMMENT ON COLUMN videos.user_id IS 'Claim sub do JWT; toda consulta e escopada por esta coluna';
COMMENT ON COLUMN videos.storage_key IS 'Chave do video original: fiapx/inputs/{userId}/{videoId}/{originalFilename}';
COMMENT ON COLUMN videos.zip_key IS 'Chave do ZIP de frames: fiapx/outputs/{userId}/{videoId}.zip';
COMMENT ON COLUMN videos.status IS 'RECEIVED, QUEUED, PROCESSING, COMPLETED ou FAILED; os dois ultimos sao finais';
COMMENT ON COLUMN videos.attempts IS 'Tentativas de processamento consumidas pelo worker antes da DLQ';
COMMENT ON INDEX idx_videos_user_status_created IS 'Atende GET /videos com filtro de status';
COMMENT ON INDEX idx_videos_user_created IS 'Atende GET /videos sem filtro de status';

-- ---- V2__criar_tabela_outbox_events.sql ----
CREATE TABLE outbox_events (
    id UUID PRIMARY KEY,
    aggregate_id UUID NOT NULL,
    event_type VARCHAR(60) NOT NULL,
    payload TEXT NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    last_error VARCHAR(1000),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    published_at TIMESTAMP,
    CONSTRAINT chk_outbox_attempts CHECK (attempts >= 0)
);

CREATE INDEX idx_outbox_pendentes ON outbox_events (created_at)
    WHERE published_at IS NULL;

CREATE INDEX idx_outbox_aggregate ON outbox_events (aggregate_id);

COMMENT ON TABLE outbox_events IS 'Eventos gravados na mesma transacao do agregado e publicados depois no RabbitMQ';
COMMENT ON COLUMN outbox_events.aggregate_id IS 'Id do video que originou o evento';
COMMENT ON COLUMN outbox_events.event_type IS 'Routing key do evento no exchange fiapx.video';
COMMENT ON COLUMN outbox_events.payload IS 'Corpo JSON do evento, ja no formato do contrato';
COMMENT ON COLUMN outbox_events.published_at IS 'Nulo enquanto o broker nao confirmou a publicacao';
COMMENT ON INDEX idx_outbox_pendentes IS 'Indice parcial que o dispatcher varre a cada ciclo';
