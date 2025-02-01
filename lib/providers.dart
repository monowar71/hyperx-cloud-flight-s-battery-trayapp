import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/battery_service.dart';
import 'services/tray_service.dart';

final trayProvider = Provider((ref) {
  return TrayService(onUpdateIntervalChanged: (int interval) {});
});

final batteryProvider = StateNotifierProvider<BatteryService, String>(
      (ref) {
    final trayService = ref.read(trayProvider);
    return BatteryService(trayService);
  },
);
