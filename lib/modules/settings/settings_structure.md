/modules/settings/
├── settings_module.dart          # Registro do módulo
├── models/
│   └── settings_model.dart       # Modelo de dados
├── providers/
│   ├── settings_provider.dart    # Estado global (Riverpod)
│   └── settings_repository_provider.dart
├── repositories/
│   └── settings_repository.dart  # Lógica de persistência
├── screens/
│   └── settings_screen.dart      # Tela principal
├── widgets/
│   ├── setting_card.dart         # Card reutilizável
│   ├── appearance_section.dart
│   ├── typography_section.dart
│   ├── backup_section.dart
│   ├── security_section.dart
│   ├── notifications_section.dart
│   ├── language_section.dart
│   ├── account_section.dart
│   └── support_section.dart
└── services/
    ├── settings_sync_service.dart # Sincronização com backend
    └── backup_service.dart        # Backup/Restore
