// core/background/background_sync_config.dart

class BackgroundSyncConfig {
  final bool autoSyncEnabled;
  final Duration syncInterval;
  final Duration minimumSyncInterval;
  final bool wifiOnly;
  final bool requireCharging;
  final bool requireBatteryNotLow;
  final bool requireDeviceIdle;
  final int minimumBatteryLevel;
  final bool syncOnCharging;
  final bool syncOnWifiConnect;
  final int syncWindowStart; // hora
  final int syncWindowEnd; // hora
  final String apiBaseUrl;
  
  const BackgroundSyncConfig({
    required this.autoSyncEnabled,
    required this.syncInterval,
    required this.minimumSyncInterval,
    required this.wifiOnly,
    required this.requireCharging,
    required this.requireBatteryNotLow,
    required this.requireDeviceIdle,
    required this.minimumBatteryLevel,
    required this.syncOnCharging,
    required this.syncOnWifiConnect,
    required this.syncWindowStart,
    required this.syncWindowEnd,
    required this.apiBaseUrl,
  });
  
  factory BackgroundSyncConfig.defaults() {
    return const BackgroundSyncConfig(
      autoSyncEnabled: false,
      syncInterval: Duration(hours: 6),
      minimumSyncInterval: Duration(minutes: 15),
      wifiOnly: true,
      requireCharging: false,
      requireBatteryNotLow: true,
      requireDeviceIdle: false,
      minimumBatteryLevel: 20,
      syncOnCharging: true,
      syncOnWifiConnect: false,
      syncWindowStart: 6,
      syncWindowEnd: 23,
      apiBaseUrl: '',
    );
  }
  
  BackgroundSyncConfig copyWith({
    bool? autoSyncEnabled,
    Duration? syncInterval,
    Duration? minimumSyncInterval,
    bool? wifiOnly,
    bool? requireCharging,
    bool? requireBatteryNotLow,
    bool? requireDeviceIdle,
    int? minimumBatteryLevel,
    bool? syncOnCharging,
    bool? syncOnWifiConnect,
    int? syncWindowStart,
    int? syncWindowEnd,
    String? apiBaseUrl,
  }) {
    return BackgroundSyncConfig(
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      syncInterval: syncInterval ?? this.syncInterval,
      minimumSyncInterval: minimumSyncInterval ?? this.minimumSyncInterval,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      requireCharging: requireCharging ?? this.requireCharging,
      requireBatteryNotLow: requireBatteryNotLow ?? this.requireBatteryNotLow,
      requireDeviceIdle: requireDeviceIdle ?? this.requireDeviceIdle,
      minimumBatteryLevel: minimumBatteryLevel ?? this.minimumBatteryLevel,
      syncOnCharging: syncOnCharging ?? this.syncOnCharging,
      syncOnWifiConnect: syncOnWifiConnect ?? this.syncOnWifiConnect,
      syncWindowStart: syncWindowStart ?? this.syncWindowStart,
      syncWindowEnd: syncWindowEnd ?? this.syncWindowEnd,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'autoSyncEnabled': autoSyncEnabled,
      'syncIntervalMinutes': syncInterval.inMinutes,
      'minimumSyncIntervalMinutes': minimumSyncInterval.inMinutes,
      'wifiOnly': wifiOnly,
      'requireCharging': requireCharging,
      'requireBatteryNotLow': requireBatteryNotLow,
      'requireDeviceIdle': requireDeviceIdle,
      'minimumBatteryLevel': minimumBatteryLevel,
      'syncOnCharging': syncOnCharging,
      'syncOnWifiConnect': syncOnWifiConnect,
      'syncWindowStart': syncWindowStart,
      'syncWindowEnd': syncWindowEnd,
      'apiBaseUrl': apiBaseUrl,
    };
  }
  
  factory BackgroundSyncConfig.fromJson(Map<String, dynamic> json) {
    return BackgroundSyncConfig(
      autoSyncEnabled: json['autoSyncEnabled'] as bool,
      syncInterval: Duration(minutes: json['syncIntervalMinutes'] as int),
      minimumSyncInterval: Duration(minutes: json['minimumSyncIntervalMinutes'] as int),
      wifiOnly: json['wifiOnly'] as bool,
      requireCharging: json['requireCharging'] as bool,
      requireBatteryNotLow: json['requireBatteryNotLow'] as bool,
      requireDeviceIdle: json['requireDeviceIdle'] as bool,
      minimumBatteryLevel: json['minimumBatteryLevel'] as int,
      syncOnCharging: json['syncOnCharging'] as bool,
      syncOnWifiConnect: json['syncOnWifiConnect'] as bool,
      syncWindowStart: json['syncWindowStart'] as int,
      syncWindowEnd: json['syncWindowEnd'] as int,
      apiBaseUrl: json['apiBaseUrl'] as String,
    );
  }
}
