import 'dart:io';
import 'package:tray_manager/tray_manager.dart';

class TrayService with TrayListener {
  String _batteryStatus = "Checking...";
  final List<int> updateIntervalList = [1, 5, 10, 15, 30, 60, 120];
  int _currentUpdateInterval = 10;
  void Function(int) onUpdateIntervalChanged;

  TrayService({required this.onUpdateIntervalChanged}) {
    trayManager.addListener(this);
    _initTray();
  }

  Future<void> _initTray() async {
    try {
      await trayManager.setIcon('assets/headset.png');
      await _updateTrayMenu();
    } catch (e) {
      print("Error initializing tray: $e");
    }
  }

  Future<void> _updateTrayMenu() async {
    final menu = Menu(
      items: [
        MenuItem(label: 'Battery: ${_batteryStatus}', disabled: true),
        MenuItem.separator(),
        MenuItem.submenu(
          key: 'update_interval',
          label: 'Update Interval',
            submenu: Menu(
              items: updateIntervalList.map((e) =>
                  _createIntervalMenuItem(e)).toList(),
            )
        ),
        MenuItem.separator(),
        MenuItem(key: 'exit_app', label: 'Exit App'),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  MenuItem _createIntervalMenuItem(int interval) {
    return MenuItem(
      key: 'interval_$interval',
      label: '$interval sec ${_currentUpdateInterval == interval ? '✓' : ''}',
    );
  }

  void updateBatteryStatus(String status) async {
    _batteryStatus = status;
    await trayManager.setTitle(status);
    await _updateTrayMenu();
  }

  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'exit_app') {
      exitApp();
    } else if (menuItem.key?.startsWith('interval_') ?? false) {
      int selectedInterval = int.parse(menuItem.key!.split('_')[1]);
      _currentUpdateInterval = selectedInterval;
      onUpdateIntervalChanged(selectedInterval);
      _updateTrayMenu();
    }
  }

  void exitApp() {
    trayManager.destroy();
    exit(0);
  }

  void dispose() {
    trayManager.removeListener(this);
  }
}
