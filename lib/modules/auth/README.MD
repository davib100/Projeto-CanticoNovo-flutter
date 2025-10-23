# 🔐 Auth Module - Cântico Novo

Módulo de autenticação completo com suporte a OAuth e gerenciamento de sessão seguro.

## ✨ Funcionalidades

- ✅ Login com email/senha
- ✅ Login com Google OAuth
- ✅ Registro de usuários
- ✅ Redefinição de senha
- ✅ Sessão persistente com refresh tokens rotativos
- ✅ Single-device enforcement
- ✅ Criptografia de tokens com `flutter_secure_storage`
- ✅ Validação robusta de formulários
- ✅ Indicador de força de senha
- ✅ Logs estruturados para observabilidade

## 🏗️ Arquitetura

auth/
├─ auth_module.dart                    # Registro do módulo
├─ screens/ 
│  ├── login_screen.dart
│  ├── register_screen.dart
│  └── reset_password_screen.dart
├── widgets/
│   ├── auth_header.dart
│   ├── social_auth_button.dart
│   ├── password_strength_indicator.dart
│   └── auth_text_field.dart
├── providers/
│   └── auth_provider.dart
├── entities/
│   └── user_entity.dart
│  ├── repositories/
│  │   └── auth_repository.dart
│  └── auth_repository_impl.dart
├─── usecases/
│    ├── login_usecase.dart
│    ├── register_usecase.dart
│    ├── logout_usecase.dart
│    └── reset_password_usecase.dart
├── models/
│   ├── user_model.dart
│   └── session_model.dart
├── datasources/
│   ├── auth_remote_datasource.dart
│   └── auth_local_datasource.dart
└── repositories/
│      
└─ core/
   ├── auth_constants.dart
   └── auth_validators.dart


## 🔄 Fluxo de Autenticação

1. **Login** → Backend valida → Retorna token JWT + refresh token
2. **Token** salvo no `flutter_secure_storage`
3. **Session** salva no SQLite local
4. **DeviceId** validado no backend (single-device)
5. **Refresh automático** quando token expira

## 🔒 Segurança

- Tokens JWT com expiração de 1 hora
- Refresh tokens rotativos (30 dias)
- Criptografia AES-256 nativa do sistema
- Single-device enforcement
- Logout remoto via backend

## 📊 Observabilidade

Todos os eventos são logados:
- Tentativas de login (sucesso/falha)
- Registro de usuários
- Redefinição de senha
- Logout e revogação de sessão

## 🧪 Testes

flutter test modules/auth/test


## 📝 Uso

// Login
final result = await ref.read(authStateProvider.notifier).login(
email: 'user@example.com',
password: 'SecurePass123',
);

// Registro
final result = await ref.read(authStateProvider.notifier).register(
fullName: 'João Silva',
email: 'joao@example.com',
password: 'SecurePass123',
);

// Logout
await ref.read(authStateProvider.notifier).logout();

## 🔗 Integração com Backend

Endpoints esperados:

- `POST /auth/login` - Autenticação
- `POST /auth/register` - Registro
- `POST /auth/google` - OAuth Google
- `POST /auth/reset-password` - Redefinir senha
- `POST /auth/refresh` - Renovar token
- `POST /auth/logout` - Encerrar sessão

---

**Desenvolvido para o projeto Cântico Novo** 🎵
