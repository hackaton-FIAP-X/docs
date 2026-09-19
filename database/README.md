# database

## `schema.sql` — entregável do PLT-9

DDL consolidado das duas bases (`authdb` e `videodb`). É um **artefato gerado**:
a fonte de verdade são as migrations Flyway dentro de cada serviço.

| Base | Origem |
|---|---|
| `authdb` | `auth-service/src/main/resources/db/migration/` |
| `videodb` | `video-service/src/main/resources/db/migration/` |

Em execução normal quem aplica o schema é o Flyway, no start de cada serviço.
Este arquivo existe como entregável obrigatório do enunciado e para inspeção do
schema completo num lugar só.

## Regerar após uma migration nova

Do diretório raiz do workspace (com os repos lado a lado):

```bash
./docs/database/generate-schema.sh
```

O script relê as migrations na ordem de versão e reescreve `schema.sql`.
A CI do repo `docs` aplica o resultado num PostgreSQL 16 limpo a cada PR — se o
`schema.sql` divergir ou não rodar em base vazia, o pipeline fica vermelho.

## Nota sobre foreign keys entre serviços

`videos.user_id` guarda o claim `sub` do JWT e **não** tem FK para `users`:
as tabelas vivem em databases diferentes e o PostgreSQL não faz FK entre bases.
Numa fronteira de microsserviço a integridade referencial vem do token e dos
eventos, não do banco.
