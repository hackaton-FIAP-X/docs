# JWT Claims Specification

## Versão: 1.0
## Compatível com: auth-service v1, video-service v1, API Gateway

---

## Claims Obrigatórios (Registered Claims)

| Claim | Tipo | Descrição | Exemplo |
|-------|------|-----------|---------|
| `sub` | string | Subject - Identificador único do usuário (UUID) | `"a1b2c3d4-e5f6-7890-abcd-ef1234567890"` |
| `email` | string | Email do usuário (usado como login) | `"joao.silva@oficina.com"` |
| `name` | string | Nome completo do usuário | `"João Silva"` |
| `iss` | string | Issuer - Emissor do token | `"https://auth.oficina.example.com"` |
| `exp` | integer | Expiration Time - Unix timestamp (segundos desde epoch) | `1724515200` |

---

## Claims Adicionais (Private Claims)

| Claim | Tipo | Descrição | Exemplo |
|-------|------|-----------|---------|
| `role` | string | Perfil de acesso | `"CLIENTE"`, `"MECANICO"`, `"ATENDENTE"`, `"GERENTE"`, `"ADMIN"` |
| `cpf_cnpj` | string | CPF (11 dígitos) ou CNPJ (14 dígitos) sem formatação | `"12345678901"` |
| `client_id` | string | UUID do cliente (apenas para role CLIENTE) | `"c1d2e3f4-5678-90ab-cdef-1234567890ab"` |
| `permissions` | array[string] | Permissões granulares | `["video:upload", "video:read", "os:create"]` |

---

## Exemplo de Payload Decodificado

```json
{
  "sub": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "email": "joao.silva@oficina.com",
  "name": "João Silva",
  "role": "CLIENTE",
  "cpf_cnpj": "12345678901",
  "client_id": "c1d2e3f4-5678-90ab-cdef-1234567890ab",
  "permissions": ["video:upload", "video:read", "os:create"],
  "iss": "https://auth.oficina.example.com",
  "exp": 1724515200,
  "iat": 1724511600,
  "jti": "tok_550e8400-e29b-41d4-a716-446655440000"
}
```

---

## Configuração de Expiração

| Token Type | Expiração | Configuração |
|------------|-----------|--------------|
| Access Token | 1 hora (3600s) | `JWT_EXPIRATION=3600000` (ms) |
| Refresh Token | 7 dias (604800s) | `JWT_REFRESH_EXPIRATION=604800000` (ms) |

---

## Algoritmo de Assinatura

- **Algoritmo**: HS256 (HMAC SHA-256)
- **Chave**: Configurada via `JWT_SECRET` (mínimo 256 bits / 32 chars)
- **Validação**: Verificar `exp`, `iss`, assinatura

---

## Validação no API Gateway / Serviços

1. Verificar assinatura com `JWT_SECRET`
2. Verificar `exp` > now
3. Verificar `iss` == `"https://auth.oficina.example.com"`
4. Extrair `sub` como `user_id` para autorização
5. Extrair `role` e `permissions` para RBAC/ABAC
6. Para `video-service`: validar escopo `video:*` nas permissions