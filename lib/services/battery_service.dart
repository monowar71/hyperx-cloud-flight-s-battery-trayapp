import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hid4flutter/hid4flutter.dart';
import 'package:collection/collection.dart';
import 'tray_service.dart';

class BatteryService extends StateNotifier<String> {
  final TrayService _trayService;
  HidDevice? _device;
  StreamSubscription<int>? _subscription;
  final List<int> _buffer = [];
  Timer? _timer;
  int _updateInterval = 10;

  BatteryService(this._trayService) : super("Checking...") {
    _trayService.onUpdateIntervalChanged = _setUpdateInterval;
    _initialize();
  }

  Future<void> _initialize() async {
    await _findDevice();
  }

  Future<void> _findDevice() async {
    try {
      final devices = await Hid.getDevices();
      _device = devices.firstWhereOrNull(
            (d) => d.vendorId == 2385 && d.productId == 5866,
      );

      if (_device != null) {
        await _startListening();
      } else {
        _handleError("Device not found", "Device not connected");
      }
    } catch (e) {
      _handleError("Error finding device: $e", "Device not connected");
    }
  }

  Future<void> _startListening() async {
    if (_device == null) return;

    try {
      await _device!.open();
      _requestBatteryLevel();
      _startTimer();
    } catch (e) {
      _handleError("Error opening device: $e", "Error opening device");
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: _updateInterval), (_) => _requestBatteryLevel());
  }

  void _setUpdateInterval(int newInterval) {
    _updateInterval = newInterval;
    _startTimer();
  }

  Future<void> _requestBatteryLevel() async {
    if (_device == null) return;

    try {
      const reportId = 0x06;
      final request = Uint8List.fromList([
        0x00, 0x02, 0x00, 0x9a, 0x00, 0x00, 0x68,
        0x4a, 0x8e, 0x0a, 0x00, 0x00, 0x00, 0xbb, 0x02
      ]);

      await _device!.sendReport(request, reportId: reportId);

      _subscription?.cancel();
      _buffer.clear();
      _subscription = _device!.inputStream().listen(
        _handleDeviceInput,
        onError: _handleDeviceError,
        cancelOnError: true,
      );
    } catch (e) {
      _handleError("Error requesting battery: $e", "Error requesting battery");
    }
  }

  void _handleDeviceInput(int byte) {
    _buffer.add(byte);
    if (_buffer.length >= 8) {
      _processResponse(Uint8List.fromList(_buffer));
      _buffer.clear();
      _subscription?.cancel();
    }
  }

  void _handleDeviceError(dynamic error) {
    _handleError("Error reading battery: $error", "Error reading battery");
  }

  void _processResponse(Uint8List response) {
    if (response.length >= 8) {
      final battery = response[7];
      _updateBatteryStatus(battery);
    } else {
      print("No valid response received.");
    }
  }

  void _updateBatteryStatus(int battery) {
    final status = "$battery%";
    print(status);

    state = status;
    _trayService.updateBatteryStatus(status);
  }

  void _handleError(String logMessage, String userMessage) {
    print(logMessage);
    state = userMessage;
    _trayService.updateBatteryStatus(userMessage);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _timer?.cancel();
    _device?.close();
    super.dispose();
  }
}
