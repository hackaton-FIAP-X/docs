# Título

**ADR-001**: Stack local do hackathon — kind + RabbitMQ + MinIO + PostgreSQL + Redis

---

## Status

- [ ] Proposto
- [x] Aceito
- [ ] Depreciado
- [ ] Substituído por ADR-XXX

---

## Contexto

**Qual é o problema que estamos resolvendo?**

O enunciado do Hackathon (POSTECH SOAT — Fase 5, "Sistema de Processamento de
Vídeos - FIAP X") pede um sistema que:

- processa **vários vídeos ao mesmo tempo** e **não perde requisição em pico**;
- extrai as imagens (frames) do vídeo e devolve um **arquivo `.zip`**;
- é protegido por usuário e senha, lista o status dos vídeos do usuário e
  notifica em caso de erro;
- persiste dados, escala horizontalmente, tem testes e CI/CD.

A stack **recomendada pelo enunciado** é: Docker + Kubernetes (ou Compose),
RabbitMQ/Kafka, PostgreSQL + Redis, Prometheus + Grafana, GitHub Actions.

Os contratos de `docs/contracts/` foram escritos numa fase anterior ("Fase 3",
domínio "oficina") e assumem **AWS S3 + SQS + API Gateway + Lambda** e
**transcoding multi-perfil** (720p/480p/thumbnails). Isso conflita com:

- o entregável real (frames → `.zip`, não transcoding);
- a viabilidade de rodar e **demonstrar em 10 minutos** sem conta AWS;
- o que já está no scaffold dos serviços (Spring Boot 3.3 / Java 21 / Maven,
  `spring-boot-starter-amqp` no `video-processor`, sem SDK de SQS).

Restrições: time pequeno, prazo curto, precisa rodar em máquina de dev e numa
demo gravada; a narrativa de escalabilidade (HPA sob carga) precisa ser visível.

---

## Decisão

Adotamos, para o alvo local e de demonstração do hackathon:

| Capacidade | Escolha |
|---|---|
| Orquestração | **kind** (Kubernetes-in-Docker), 1 control-plane + 2 workers |
| Mensageria | **RabbitMQ** (`spring-boot-starter-amqp`) |
| Object storage | **MinIO** (API compatível com S3; SDK AWS S3 v2 aponta para o endpoint do MinIO) |
| Banco | **PostgreSQL** (um database por serviço: `authdb`, `videodb`) |
| Cache / contadores | **Redis** |
| E-mail (dev) | **Mailhog** |
| Fluxo de processamento | vídeo → **extração de frames (FFmpeg `-vf fps=1`)** → **`.zip`** no object storage |
| Assinatura de JWT | segredo **simétrico** (HMAC), via `JWT_SECRET` (par assimétrico/JWKS fica como evolução) |

O `docs/contracts/` continua sendo a referência de **forma** (schemas de evento,
DDL, claims do JWT, layout de chaves de bucket). O que muda é o **substrato**:
onde os contratos dizem "S3" leia "MinIO"; onde dizem "SQS `video-uploaded-queue`"
leia "fila RabbitMQ"; o layout de chaves (`uploads/{video_id}/…`,
`processed/{video_id}/…`) é mantido.

Esta ADR **substitui a premissa AWS S3/SQS/API-Gateway** dos contratos congelados
para o alvo local/hackathon. Um provedor gerenciado em nuvem pode voltar numa
ADR futura sem invalidar os schemas.

---

## Consequências

### Positivas
- ✅ Ambiente inteiro sobe com `kind` + `kubectl apply -k`, sem conta de nuvem.
- ✅ HPA, Ingress e reschedule de pod ficam **demonstráveis** (trilha PLT-3).
- ✅ Alinha com o scaffold existente (amqp já no `video-processor`).
- ✅ Entregável correto: frames → `.zip`, como no PDF.
- ✅ MinIO fala o protocolo S3 — o código usa o mesmo SDK que usaria na AWS.

### Negativas / Riscos
- ❌ Divergência entre `docs/contracts/` (texto "S3/SQS") e a implementação —
  mitigado atualizando os contratos no mesmo PR (regra de congelamento).
- ❌ RabbitMQ não tem replay/retention como Kafka — suficiente para o escopo
  (fila de trabalho com DLQ), mas limita casos de event-sourcing futuros.
- ❌ `kind delete cluster` apaga os PVCs; não há persistência entre recriações
  do cluster.
- ❌ JWT simétrico exige compartilhar `JWT_SECRET` entre auth e serviços
  validadores (sem validação offline por chave pública).

### Neutras / Trade-offs
- ⚖️ kind aproxima a demo de um Kubernetes real, ao custo de mais recurso de
  máquina que um `docker-compose` puro (que segue disponível como quickstart —
  PLT-4).
- ⚖️ MinIO/RabbitMQ locais imitam S3/SQS; um dia de trabalho para portar para
  os serviços gerenciados caso o projeto siga.

---

## Alternativas Avaliadas

| Alternativa | Prós | Contras | Por que não |
|---|---|---|---|
| AWS real (S3 + SQS + EKS), como nos contratos | Produção de verdade, sem imitação | Precisa de conta/credenciais/custo; difícil de demonstrar e reproduzir; desalinha do entregável (transcoding vs frames) | Inviável no prazo e no formato de demo do hackathon |
| LocalStack (S3 + SQS emulados) | Mantém o texto dos contratos sem mudar código | Camada extra frágil; SQS no LocalStack tem limitações; sem ganho sobre MinIO/RabbitMQ para o escopo | Complexidade sem retorno |
| Kafka no lugar de RabbitMQ | Retention, replay, throughput | Mais pesado para subir no kind; scaffold já usa `spring-boot-starter-amqp` | Excesso para uma fila de trabalho com DLQ |
| Só `docker-compose` (sem Kubernetes) | Mais simples e leve | Perde a narrativa de HPA/escala horizontal exigida pela apresentação | Fica como quickstart complementar, não como alvo |

---

## Plano de Implementação

1. [x] Criar o repositório `infra/` (polyrepo, ao lado de auth/video/processor/docs).
2. [x] `kind/kind-config.yaml` — 1 control-plane + 2 workers.
3. [x] **PLT-2**: manifests de Postgres, RabbitMQ, MinIO, Redis (StatefulSet +
   PVC) e Mailhog (Deployment), no namespace `fiapx`, com Job de criação dos
   buckets `fiapx-videos` / `fiapx-outputs`.
4. [x] **PLT-1**: Deployment + Service + ConfigMap + Secret (via `secretGenerator`)
   para os três serviços, com probes no Actuator.
5. [x] Scripts `kind-up` / `build-images` / `load-images` / `deploy-infra` /
   `deploy-apps` / `verify` / `down`.
6. [x] Atualizar `docs/contracts/README.md` e `docs/contracts/storage/bucket-layout.md`
   (substrato local) e o `README.md` da raiz.
7. [ ] PLT-3: Ingress NGINX + HPA do worker.
8. [ ] PLT-4: `docker-compose` completo + Makefile.
9. [ ] PLT-7: Prometheus + Grafana.

---

## Métricas de Sucesso

- `./scripts/verify.sh` passa: infra e serviços `Running`, PVCs `Bound`.
- `kubectl delete pod postgres-0` não perde dado (linha de teste sobrevive).
- Os três serviços conectam a Postgres/RabbitMQ/MinIO/Redis pelo **DNS interno**
  do cluster.
- Outro dev sobe tudo do zero em máquina limpa em < 15 min seguindo o
  `infra/README.md`.
- Nenhum segredo em texto plano rastreado pelo git.

---

## Referências

- Enunciado: "POSTECH - SOAT - Fase 5 - Hackathon — Sistema de Processamento de Vídeos - FIAP X".
- [kind — Kubernetes IN Docker](https://kind.sigs.k8s.io/)
- [MinIO — S3-compatible object storage](https://min.io/docs/minio/kubernetes/upstream/)
- [Spring Boot — Kubernetes probes / Actuator](https://docs.spring.io/spring-boot/reference/actuator/endpoints.html#actuator.endpoints.kubernetes-probes)
- Contratos relacionados: `docs/contracts/storage/bucket-layout.md`,
  `docs/contracts/events/*.json`, `docs/contracts/jwt/claims.md`.

---

## Metadados

| Campo | Valor |
|---|---|
| Autor | @denisrodrigues |
| Data | 2026-09-01 |
| Revisores | @marcosjesus, time FIAP X |
| Próxima revisão | 2027-03-01 (6 meses) |

---

## Changelog

| Data | Versão | Autor | Mudança |
|---|---|---|---|
| 2026-09-01 | 1.0 | @denisrodrigues | Criação inicial — stack local kind/RabbitMQ/MinIO/Postgres/Redis (PLT-1, PLT-2) |
