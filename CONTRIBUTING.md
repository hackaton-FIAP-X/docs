# Guia de Contribuição

Obrigado por contribuir! Siga este guia para manter consistência e qualidade.

## Antes de Começar

1. Leia [Working Agreements](working-agreements.md) — DoD, branches, commits, reviews
2. Verifique issues abertas ou crie uma nova com contexto claro
3. Discuta mudanças grandes (arquitetura, breaking changes) em issue antes de codar

## Fluxo de Trabalho

### 1. Crie a branch

```bash
git checkout main && git pull
git checkout -b feat/JIRA-123-nova-funcionalidade
# ou fix/, chore/, docs/, test/
```

### 2. Desenvolva

- Commits pequenos e atômicos (Conventional Commits)
- Testes para código novo (unit + integração)
- Atualize documentação junto (README, OpenAPI, CHANGELOG)

### 3. Valide localmente

```bash
# Build + testes + lint
./gradlew build check

# Cobertura (não deve cair)
./gradlew jacocoTestReport
```

### 4. Abra Pull Request

- Base: `main`
- Preencha o template `.github/PULL_REQUEST_TEMPLATE.md`
- Checklist do DoD completo
- Link para issue/JIRA

### 5. Code Review

- Aguarde 1 aprovação + CI verde
- Resolva conflitos se houver
- Self-merge após aprovação

## Padrões de Código

### Kotlin/Spring Boot

- `ktlint` + `detekt` (config no repo)
- Construtores primários, data classes, sealed classes
- Extensions functions > utils estáticos
- Coroutines + Flow para assíncrono
- `@Valid` + Bean Validation nos DTOs

### Testes

| Camada | Framework | Cobertura alvo |
|--------|-----------|----------------|
| Unitário | JUnit 5, MockK | 80%+ |
| Integração | Testcontainers, SpringBootTest | 70%+ |
| Contrato | Pact (consumer-driven) | Contratos críticos |

### Commits

```
feat(auth): adiciona refresh token rotation

- Implementa rotação de refresh token com blacklist
- Adiciona testes de integração
- Atualiza OpenAPI

Closes AUTH-123
```

## Reporting Bugs

Use template `.github/ISSUE_TEMPLATE/bug_report.md` com:
- Passos para reproduzir
- Comportamento esperado vs atual
- Logs/stacktrace
- Ambiente (local, staging, prod)

## Sugerindo Features

Use template `.github/ISSUE_TEMPLATE/feature_request.md` com:
- Problema que resolve
- Solução proposta
- Alternativas consideradas
- Impacto em outros serviços

## Dúvidas?

- Slack: `#hackathon-fiap-dev`
- Issues: GitHub Issues deste repo
- Pair programming: combine no Slack

---

**Lembre-se**: Pequenos PRs, review rápido, deploy contínuo.