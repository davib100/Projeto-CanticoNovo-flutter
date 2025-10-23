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
├── repositories/
│   └── auth_repository.dart
│   └── auth_repository_impl.dart
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
│      
└─ core/
   ├── auth_constants.dart
   └── auth_validators.dart
