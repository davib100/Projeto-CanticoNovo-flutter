# 🎵 Projeto Cântico Novo — Arquitetura Técnica e Estratégias

## 🧩 Visão Geral

O Cântico Novo é um aplicativo multiplataforma (Flutter) com arquitetura baseada em microfrontends orquestrados e um backend centralizado (ExpressJS).
Seu objetivo é permitir o gerenciamento completo de letras, categorias e sincronização inteligente entre armazenamento local e nuvem (Google Drive), mantendo desempenho, segurança e rastreabilidade total.

## ⚙️ Estrutura Geral do Projeto

### 🏗️ Organização Global

/project-root
│
├── /frontend (Microfrontend Flutter)
│   ├── /core
│   │   ├── app_orchestrator.dart
│   │   ├── module_registry.dart
│   │   ├── queue/
│   │   ├── db/
│   │   ├── migrations/
│   │   ├── sync/
│   │   ├── background/
│   │   ├── services/
│   │   ├── security/
│   │   └── observability/
│   │
│   ├── /modules
│   │   ├── /auth (login,register and password reset)
│   │   ├── /upload
│   │   ├── /terms
│   │   ├── /search
│   │   ├── /library
│   │   ├── /quickaccess
│   │   ├── /lyrics
│   │   ├── /settings
│   │   └── /karaoke
│   │
│   ├── /shared
│   │   ├── widgets/
│   │   ├── components/
│   │   └── utils/
│   │
│   ├── /migrations
│   ├── /assets
│   └── main.dart
│
└── /backend (NodeJS + Express + SQLite)
    ├── /routes
    ├── /controllers
    ├── /models
    ├── /services
    ├── /middlewares
    ├── /utils
    ├── /config
    └── server.mjs

## 🧠 ARQUITETURA FRONTEND (Flutter)

### 🪄 App Orchestrator (Core)

Responsável por inicializar todo o ecossistema do app.
Durante o boot, o AppOrchestrator:
*   Varre os módulos registrados com @AppModule().
*   Faz o registro automático via reflexão.
*   Gera logs detalhados de cada passo do boot:
    *   Nome do módulo.
    *   Tipo de persistência (direta ou fila).
    *   Status da ação (⏳, ✅, ❌).

#### 📋 Exemplo de log exibido na tela de debug (em tempo real):

| Timestamp  | Módulo      | Persistência        | Ação         | Status |
| ---------- | ----------- | ------------------- | ------------ | ------ |
| 10:02:01   | LibraryModule | Fila (QueueManager) | createBook() | ✅ Sucesso |
| 10:02:04   | AuthModule  | Direto (DB)         | createUser() | ✅ Sucesso |
| 10:02:10   | QuickAccess | Fila (QueueManager) | trackClick() | ⏳ Em fila |

### 🧰 QueueManager

*   Gerencia operações assíncronas de escrita.
*   Apenas módulos com dados críticos e sincronizáveis usam a fila:
    *   Library, QuickAccess, Lyrics, Categories.
*   Tipos de dados locais (tema, idioma, sessão) usam escrita direta no banco.
*   O QueueManager é instanciado pelo AppOrchestrator e exposto globalmente via Provider (Riverpod).

### 💾 Banco de Dados Local (SQLite + Drift)

*   O app utiliza Drift com sqlite3_flutter_libs (modo WAL ativo).
*   Acesso estruturado via DatabaseAdapter, com métodos genéricos:
    *   `insert()`, `update()`, `delete()`, `query()`.
*   Estrutura:
    ```
    /core/db/
      ├── database_adapter.dart
      ├── schema_registry.dart
      ├── migration_manager.dart
    ```
*   `/core/migrations/` contém os scripts de migração.

### 🔄 Sincronização e Conflitos

*   Módulo `/core/sync`:
    *   Mantém tabela `sync_log` com status: `pending`, `synced`, `conflict`, `error`.
    *   Adota `last-write-wins` para entidades simples.
    *   Exibe interface de reconciliação manual em casos críticos.
    *   Backend executa reconciliação final.
    *   Nenhum cache duplicado de respostas do servidor — somente a versão final aplicada é mantida.

### 🕐 Background Sync (WorkManager)

*   Controlado pelo AppOrchestrator, mas ativado apenas quando o usuário habilita o backup automático.
*   Sincroniza apenas via Wi-Fi.
*   Botão manual “Sincronizar agora” disponível com feedback:
    *   ⏳ Carregando
    *   ✅ Sucesso
    *   ❌ Falha
*   Mostra horário da última sincronização.

### 🔐 Sessão e Autenticação

*   Login via OAuth (Google, Microsoft, Facebook).
*   Tokens armazenados com `flutter_secure_storage` (criptografia nativa).
*   Sessão válida apenas com confirmação do backend (single-device enforcement).
*   Backend gera `deviceId` único.
*   Refresh tokens rotativos — renovados automaticamente.
*   Caso inválido, o app exige novo login.

### 🗃️ Backup e Restore

*   Backup local e na nuvem via Google Drive API.
*   Arquivos compactados e criptografados com AES-256, utilizando senha fixa interna.
*   Restauração via painel “Configurações → Restaurar Backup”.
*   Banco local e nuvem sincronizados periodicamente.

### ⚙️ Estrutura de Módulos (Microfrontends)

Cada módulo é independente e registrado automaticamente:

*   **/modules/auth**: Login, logout, refresh de tokens, single-device check Registro, validação de termos.
*   **/modules/upload: Upload de músicas.
*   **/modules/terms**: Exibição e aceite de Termos de Uso.
*   **/modules/search**: Busca avançada por título/estrofe. Sugestões e histórico.
*   **/modules/library**: Organização de letras, categorias. Integração com QueueManager.
*   **/modules/quickaccess**: Lista temporária de 10 músicas (24h). Reordenação, adição e exclusão.
*   **/modules/lyrics**: Exibição, rolagem automática, edição, reprodução musical.
*   **/modules/settings**: Idioma, backup, categorias, logout, painel local de logs e erros.
*   **/modules/karaoke**: Sincronização de letras por timestamp e playback com destaque visual.

## 🌐 ARQUITETURA BACKEND (ExpressJS)

### 📁 Estrutura

```
/backend
│
├── /routes
│   ├── authRoutes.mjs
│   ├── libraryRoutes.mjs
│   ├── searchRoutes.mjs
│   ├── syncRoutes.mjs
│   ├── quickAccessRoutes.mjs
│   ├── lyricsRoutes.mjs
│   ├── settingsRoutes.mjs
│   ├── karaokeRoutes.mjs
│   └── backupRoutes.mjs
│
├── /controllers
│   ├── authController.mjs
│   ├── libraryController.mjs
│   ├── syncController.mjs
│   └── ...
│
├── /models
│   ├── userModel.mjs
│   ├── songModel.mjs
│   ├── categoryModel.mjs
│   ├── sessionModel.mjs
│   └── ...
│
├── /services
│   ├── authService.mjs
│   ├── syncService.mjs
│   ├── driveService.mjs
│   ├── queueProcessor.mjs
│   └── ...
│
├── /middlewares
│   ├── authMiddleware.mjs
│   ├── errorHandler.mjs
│   ├── requestLogger.mjs
│   └── ...
│
├── /config
│   ├── database.mjs (SQLite)
│   ├── sentry.mjs
│   ├── env.mjs
│   └── app.mjs
│
└── server.mjs
```

### 🔒 Autenticação

*   JWT + Refresh Tokens rotativos.
*   `deviceId` associado ao token no banco.
*   Validação no middleware `authMiddleware`.
*   Logout e revogação remota de sessão anterior.

### 💽 Banco de Dados

*   SQLite por padrão, com migração planejada para PostgreSQL.
*   Mapeamento 1:1 com as entidades do app (Library, Lyrics, etc.).
*   Logs e tabelas de fila compatíveis com QueueManager.

### 🔁 Sincronização

*   Endpoints REST:
    *   `/sync/push` → recebe batches de operações pendentes.
    *   `/sync/pull` → envia atualizações do servidor.
*   Conciliação automática ou manual.
*   Resposta simplificada para o cliente aplicar diretamente no banco local.

### 📡 Notificações

*   Integração futura com Firebase ou OneSignal.
*   Suporte a:
    *   Novas músicas
    *   Backup concluído
    *   Lembretes diários
    *   Atualizações do app
*   Configuração de preferências em `/modules/settings`.

### 🧠 Observabilidade

*   Sentry configurado com tracing distribuído:
    *   Projeto separado para Flutter (`flutter-app`) e backend (`backend-core`).
    *   Correlação automática entre erros do app e backend.
*   Painel de logs local no app (modo dev/teste):
    *   Logs estruturados.
    *   Status de sincronização.
    *   Erros e métricas.

### 🔐 Segurança

*   Tokens e backups criptografados.
*   Criptografia AES-256 com senha fixa local.
*   Armazenamento seguro via `flutter_secure_storage`.
*   HTTPS obrigatório para comunicação backend ↔ app.

## 🚀 Conclusão

O Cântico Novo combina:
*   Arquitetura modular e reativa.
*   Sincronização híbrida (fila + direta).
*   Controle centralizado via orquestrador.
*   Logs e rastreabilidade total em tempo real.
*   Segurança de nível enterprise (JWT rotativo + AES-256).

Essa base garante performance, segurança, manutenção escalável e uma experiência fluida tanto para o usuário final quanto para o desenvolvedor.

## Plano de Ação

*   [x] Criar o arquivo `blueprint.md`.
*   [ ] Criar a estrutura de pastas do frontend.
*   [ ] Aguardar e refatorar os scripts do usuário.
