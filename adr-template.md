# ADR Template

> Architecture Decision Record — Registra decisões arquiteturais significativas.
> Use um arquivo por decisão: `docs/adr/NNN-titulo-kebab-case.md`

---

## Título

**ADR-NNN**: <Título curto e descritivo>

Exemplo: `ADR-003: Adota Kafka para processamento assíncrono de vídeos`

---

## Status

- [ ] Proposto
- [ ] Aceito
- [ ] Depreciado
- [ ] Substituído por ADR-XXX

---

## Contexto

**Qual é o problema que estamos resolvendo?**

Descreva:
- Cenário atual e dores
- Restrições técnicas/negócio
- Alternativas consideradas (resumo)

> Exemplo: "O processamento síncrono de upload de vídeo bloqueia a API por 30s+, causando timeouts no client mobile. Precisamos desacoplar upload de transcoding."

---

## Decisão

**O que decidimos fazer?**

Declare a decisão de forma clara e imperativa.

> Exemplo: "Adotamos Apache Kafka como message broker para fila de processamento de vídeo. O video-service publica evento `VideoUploaded`; video-processor consome e executa transcoding assíncrono."

---

## Consequências

### Positivas
- ✅ Desacoplamento: API responde em <200ms
- ✅ Escalabilidade: consumers horizontais
- ✅ Resiliência: retry nativo, DLQ para falhas permanentes
- ✅ Observabilidade: métricas de lag, throughput

### Negativas / Riscos
- ❌ Complexidade operacional: cluster Kafka, monitoramento
- ❌ Eventual consistency: vídeo não disponível imediatamente
- ❌ Debugging distribuído: correlação de traces (precisa OpenTelemetry)

### Neutras / Trade-offs
- ⚖️ Latência de processamento aumenta (assíncrono), mas UX melhora (feedback imediato)
- ⚖️ Custo infra: +3 brokers Kafka em staging/prod

---

## Alternativas Avaliadas

| Alternativa | Prós | Contras | Por que não |
|-------------|------|---------|-------------|
| RabbitMQ | Simples, maduro | Menos throughput, sem log retention nativo | Requisito de replay de eventos |
| AWS SQS + Lambda | Serverless, gerenciado | Vendor lock-in, cold starts, custo variável | Multi-cloud strategy |
| Polling no DB | Zero infra | Coupling, polling overhead, não escala | Anti-pattern para event-driven |

---

## Plano de Implementação

1. [ ] Provisionar Kafka (dev: docker-compose, staging/prod: managed)
2. [ ] Definir schema Avro/Protobuf para `VideoUploaded` (Schema Registry)
3. [ ] Implementar producer no video-service (outbox pattern para garantia)
4. [ ] Implementar consumer no video-processor (idempotência via `videoId`)
5. [ ] Configurar DLQ + alerting (lag > 1000, error rate > 1%)
6. [ ] Testes de integração + chaos (kill consumer, replay)
7. [ ] Documentar runbooks (operacional)

---

## Métricas de Sucesso

- P99 API upload < 200ms
- Tempo médio processamento < 5min (1080p)
- Taxa falha processamento < 0.1%
- Zero perda de eventos (exactly-once semantics)

---

## Referências

- [Event-Driven Architecture patterns](https://martinfowler.com/articles/201701-event-driven.html)
- [Transactional Outbox Pattern](https://microservices.io/patterns/data/transactional-outbox.html)
- ADR relacionado: ADR-001 (Microservices), ADR-002 (PostgreSQL por serviço)

---

## Metadados

| Campo | Valor |
|-------|-------|
| Autor | @usuario |
| Data | YYYY-MM-DD |
| Revisores | @reviewer1, @reviewer2 |
| Próxima revisão | YYYY-MM-DD (6 meses) |

---

## Changelog

| Data | Versão | Autor | Mudança |
|------|--------|-------|---------|
| YYYY-MM-DD | 1.0 | @usuario | Criação inicial |