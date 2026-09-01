# Working Agreements

## Definition of Done (DoD)

Todo item de trabalho (story, task, bug) só é considerado **Done** quando **todos** os critérios abaixo são atendidos:

- [ ] **Compila** — Build passa sem erros (CI verde)
- [ ] **Testes passam** — Suite de testes (unitários + integração) executa com sucesso
- [ ] **Cobertura não caiu** — Code coverage ≥ threshold configurado (não regressão)
- [ ] **Endpoint documentado no OpenAPI** — Swagger/OpenAPI atualizado para endpoints novos/alterados
- [ ] **Pull request revisado por 1 pessoa** — Pelo menos 1 aprovação (`Approve`) no PR

> **Exceções**: Hotfixes críticos em produção podem ter DoD reduzido (apenas compila + testes + review), mas devem ter follow-up para completar documentação e cobertura em até 2 dias úteis.

---

## Branch Naming Convention

Padrão: `<tipo>/<JIRA-ID>-<descrição-kebab-case>`

| Tipo     | Uso                            | Exemplo                    |
|----------|--------------------------------|----------------------------|
| `feat/`  | Nova funcionalidade            | `feat/AUTH-3-login`        |
| `fix/`   | Correção de bug                | `fix/VID-7-idempotencia`   |
| `chore/` | Manutenção, refactor, tooling  | `chore/DEV-12-update-deps` |
| `docs/`  | Apenas documentação            | `docs/API-5-readme`        |
| `test/`  | Apenas testes                  | `test/PAY-9-coverage`      |

**Regras**:
- Branch name em inglês, kebab-case, max 50 chars
- JIRA ID obrigatório (para rastreabilidade)
- Delete branch remota após merge

---

## Commit Messages

Seguimos **Conventional Commits 1.0**:

```
<type>(<scope>): <descrição curta>

[corpo opcional]

[rodapé opcional]
```

**Types principais**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `ci`

**Exemplos**:
```
feat(auth): adiciona login com JWT

fix(payment): corrige idempotência no webhook Stripe

chore(deps): atualiza dependências do Spring Boot 3.2
```

---

## Pull Request Template

Local: `.github/PULL_REQUEST_TEMPLATE.md`

O template já existe e deve ser preenchido. Checklist mínimo:
- [ ] DoD atendido (ver acima)
- [ ] Testes adicionados/atualizados
- [ ] Documentação atualizada (README, OpenAPI, CHANGELOG se aplicável)
- [ ] Breaking changes documentados no rodapé do commit (`BREAKING CHANGE:`)

---

## Code Review

- **Mínimo**: 1 aprovação (`Approve`) de qualquer membro do time
- **SLA sugerido**: Review em até 4h úteis após PR aberto
- **Self-merge**: Permitido após aprovação + CI verde
- **Conflitos**: Autor resolve antes de merge

---

## Versionamento & Releases

- **SemVer** (MAJOR.MINOR.PATCH)
- Tags no formato `v1.2.3`
- `CHANGELOG.md` mantido manualmente (ou via `standard-version`)

---

## Referências Rápidas

- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)