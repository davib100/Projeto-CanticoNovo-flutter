
// /modules/settings/models/settings_model.dart

import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings_model.freezed.dart';
part 'settings_model.g.dart';

@freezed
class SettingsModel with _$SettingsModel {
  const factory SettingsModel({
    @Default('light') String theme,
    @Default('pt') String language,
    @Default(16) int fontSize,
    @Default('#f59e0b') String accentColor,
    @Default('system') String fontFamily,
    @Default(2.0) double autoScrollSpeed,
    @Default(true) bool autoBackup,
    @Default(true) bool notifications,
    @Default('09:00') String notificationTime,
    @Default(false) bool biometricLock,
    DateTime? lastBackup,
    DateTime? lastSync,
  }) = _SettingsModel;

  factory SettingsModel.fromJson(Map<String, dynamic> json) =>
      _$SettingsModelFromJson(json);
}
