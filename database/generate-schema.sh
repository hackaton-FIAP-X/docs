#!/usr/bin/env bash
# Regera docs/database/schema.sql a partir das migrations Flyway dos serviços.
# Rode a partir de qualquer lugar; espera os repos lado a lado no workspace.
set -euo pipefail

DOCS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="$(cd "${DOCS_DIR}/.." && pwd)"
AUTH_MIG="${WORKSPACE}/auth-service/src/main/resources/db/migration"
VIDEO_MIG="${WORKSPACE}/video-service/src/main/resources/db/migration"
OUT="${DOCS_DIR}/database/schema.sql"

for d in "${AUTH_MIG}" "${VIDEO_MIG}"; do
  [[ -d "$d" ]] || { echo "ERRO: migrations não encontradas em $d" >&2; exit 1; }
done

# Ordena por versão (V1, V2, V10...) e não alfabeticamente.
migrations() { find "$1" -name 'V*__*.sql' | sort -V; }

{
  cat <<HDR
-- =============================================================================
-- FIAP X - Sistema de Processamento de Videos
-- Script consolidado de criacao do banco de dados  (PLT-9)
--
-- ARQUIVO GERADO — nao edite a mao.
-- Regerar:  ./docs/database/generate-schema.sh
-- Fonte de verdade: as migrations Flyway de cada servico.
--
-- Gerado a partir de:
$(migrations "${AUTH_MIG}"  | sed "s#^${WORKSPACE}/#--   #")
$(migrations "${VIDEO_MIG}" | sed "s#^${WORKSPACE}/#--   #")
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
\\connect authdb
HDR
  while read -r f; do echo; echo "-- ---- $(basename "$f") ----"; cat "$f"; done < <(migrations "${AUTH_MIG}")

  cat <<'MID'

-- =============================================================================
-- 2) videodb  -  video-service / video-processor
--
-- `videos.user_id` guarda o claim `sub` do JWT e NAO tem foreign key para
-- users: a tabela vive em outro database e o PostgreSQL nao faz FK entre
-- bases. Numa fronteira de microsservico a integridade vem do token e dos
-- eventos, nao do banco.
-- =============================================================================
\connect videodb
MID
  while read -r f; do echo; echo "-- ---- $(basename "$f") ----"; cat "$f"; done < <(migrations "${VIDEO_MIG}")
} > "${OUT}"

echo "gerado: ${OUT} ($(wc -l < "${OUT}") linhas)"
