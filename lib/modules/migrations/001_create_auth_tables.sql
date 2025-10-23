-- Tabela de usuários
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  fullName TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  photoUrl TEXT,
  deviceId TEXT NOT NULL,
  createdAt TEXT NOT NULL,
  lastLoginAt TEXT,
  updatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de sessões
CREATE TABLE IF NOT EXISTS sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  token TEXT NOT NULL,
  refreshToken TEXT NOT NULL,
  deviceId TEXT NOT NULL,
  expiresAt TEXT NOT NULL,
  createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_deviceId ON users(deviceId);
CREATE INDEX IF NOT EXISTS idx_sessions_deviceId ON sessions(deviceId);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON sessions(token);
