import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeviceInfoService {
  final DeviceInfoPlugin _deviceInfoPlugin;

  DeviceInfoService(this._deviceInfoPlugin);

  Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        return androidInfo.id; // 'id' é o substituto para o obsoleto 'androidId'
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        return iosInfo.identifierForVendor ?? 'ios-id-unavailable';
      }
    } catch (e) {
      // Em um cenário real, registraríamos isso com o serviço de observabilidade
      return 'device-id-error';
    }
    return 'unsupported-platform';
  }
}

final deviceInfoPluginProvider = Provider<DeviceInfoPlugin>((ref) {
  return DeviceInfoPlugin();
});

final deviceInfoServiceProvider = Provider<DeviceInfoService>((ref) {
  return DeviceInfoService(ref.watch(deviceInfoPluginProvider));
});
