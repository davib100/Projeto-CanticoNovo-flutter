auth/
├─ auth_module.dart                    # Registro do módulo
├─ presentation/
│  ├── screens/
│  │   ├── login_screen.dart
│  │   ├── register_screen.dart
│  │   └── reset_password_screen.dart
│  ├── widgets/
│  │   ├── auth_header.dart
│  │   ├── social_auth_button.dart
│  │   ├── password_strength_indicator.dart
│  │   └── auth_text_field.dart
│  └── providers/
│      └── auth_provider.dart
├─ domain/
│  ├── entities/
│  │   └── user_entity.dart
│  ├── repositories/
│  │   └── auth_repository.dart
│  └── usecases/
│      ├── login_usecase.dart
│      ├── register_usecase.dart
│      ├── logout_usecase.dart
│      └── reset_password_usecase.dart
├─ data/
│  ├── models/
│  │   ├── user_model.dart
│  │   └── session_model.dart
│  ├── datasources/
│  │   ├── auth_remote_datasource.dart
│  │   └── auth_local_datasource.dart
│  └── repositories/
│      └── auth_repository_impl.dart
└─ core/
   ├── auth_constants.dart
   └── auth_validators.dart
