-- Tabela de usuários (auth-service)
-- Versão: 1.0
-- Compatível com: auth-service v1, video-service v1

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

-- Índices
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_ativo ON users(ativo);

-- Comentários
COMMENT ON TABLE users IS 'Usuários do sistema (internos e clientes)';
COMMENT ON COLUMN users.id IS 'Identificador único (UUID v4)';
COMMENT ON COLUMN users.nome IS 'Nome completo do usuário';
COMMENT ON COLUMN users.email IS 'Email único, usado como login';
COMMENT ON COLUMN users.senha IS 'Hash bcrypt da senha';
COMMENT ON COLUMN users.role IS 'Perfil de acesso: ADMIN, GERENTE, MECANICO, ATENDENTE, CLIENTE';
COMMENT ON COLUMN users.ativo IS 'Se o usuário pode autenticar';
COMMENT ON COLUMN users.data_cadastro IS 'Data de criação do registro';
COMMENT ON COLUMN users.data_atualizacao IS 'Data da última atualização';