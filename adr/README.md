# Architecture Decision Records (ADR)

Registro de decisões arquiteturais significativas do projeto.

## Como criar um ADR

1. Copie [`adr-template.md`](../adr-template.md) para `docs/adr/NNN-titulo-kebab-case.md`
   - `NNN` = número sequencial (001, 002, 003...)
   - Exemplo: `003-adota-kafka-processamento-video.md`
2. Preencha todas as seções
3. Abra PR para review do time
4. Após aprovação, marque status como **Aceito**

## Índice de ADRs

| ID | Título | Status | Data | Autor |
|----|--------|--------|------|-------|
| 001 | [Exemplo: Arquitetura Microserviços](001-microservices-architecture.md) | Aceito | 2024-01-15 | @autor |
| 002 | [Exemplo: PostgreSQL por Serviço](002-postgres-per-service.md) | Aceito | 2024-01-15 | @autor |
| 003 | [Exemplo: Kafka para Processamento Assíncrono](003-adota-kafka-processamento-video.md) | Proposto | 2024-01-20 | @autor |

> **Dica**: Mantenha esta tabela atualizada. Script sugerido para gerar automaticamente:
> ```bash
> ls docs/adr/*.md | grep -v README | sort | while read f; do
>   title=$(grep "^## Título" "$f" | cut -d: -f2- | xargs)
>   status=$(grep "^- \[" "$f" | grep -E "Aceito|Proposto|Depreciado|Substituído" | head -1 | sed 's/.*\[\(x\| \)\).*/\1/')
>   echo "| $(basename "$f" .md | cut -d- -f1) | $title | $status | ... |"
> done
> ```

## Quando criar ADR

- Escolha de tecnologia/framework principal (DB, message broker, cloud provider)
- Padrão arquitetural (event-driven, CQRS, saga, etc.)
- Decisão com impacto cross-service ou breaking change
- Trade-off não óbvio que o time deve conhecer

## Quando NÃO criar ADR

- Decisões triviais ou de implementação local
- Configurações de infra já padronizadas
- Refatorações internas sem impacto externo

## Referências

- [Documenting Architecture Decisions - Michael Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [ADR GitHub Organization](https://github.com/adr)
- [Template MADR (Markdown ADR)](https://adr.github.io/madr/)