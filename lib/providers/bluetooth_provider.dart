import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothProvider extends ChangeNotifier {
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _commandChar;
  BluetoothCharacteristic? _timeSyncChar;

  bool _isScanning = false;
  List<ScanResult> _scanResults = [];

  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice != null;
  bool get isScanning => _isScanning;
  List<ScanResult> get scanResults => _scanResults;

  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<bool>? _isScanningSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  final String serviceUuid = "19b10000-e8f2-537e-4f6c-d104768a1214";
  final String commandCharUuid = "19b10001-e8f2-537e-4f6c-d104768a1214";
  final String timeSyncCharUuid = "19b10002-e8f2-537e-4f6c-d104768a1214";

  BluetoothProvider() {
    _initBluetooth();
  }

  void _initBluetooth() {
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      _scanResults = results;
      notifyListeners();
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      _isScanning = state;
      notifyListeners();
    });
  }

  Future<void> startScan() async {
    _scanResults.clear();
    notifyListeners();
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Future<void> connect(BluetoothDevice device) async {
    await stopScan();
    try {
      await _connectionStateSubscription?.cancel();
      await device.connect(license: License.free, autoConnect: false);
      _connectedDevice = device;

      _connectionStateSubscription = device.connectionState.listen((
        BluetoothConnectionState state,
      ) async {
        if (state == BluetoothConnectionState.connected) {
          debugPrint('Device Connected! Discovering services...');
          await _discoverServices();
          debugPrint('Services Discovered. Syncing time...');
          await syncTime();
          debugPrint('Time synced. Setup complete.');
          notifyListeners();
        } else if (state == BluetoothConnectionState.disconnected) {
          debugPrint('Device Disconnected.');
          _connectedDevice = null;
          _commandChar = null;
          _timeSyncChar = null;
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('Connection error: $e');
    }
  }

  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      _commandChar = null;
      _timeSyncChar = null;
      notifyListeners();
    }
  }

  Future<void> _discoverServices() async {
    if (_connectedDevice == null) return;
    List<BluetoothService> services = await _connectedDevice!
        .discoverServices();
    for (var service in services) {
      if (service.uuid.toString() == serviceUuid) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid.toString() == commandCharUuid) {
            _commandChar = characteristic;
          } else if (characteristic.uuid.toString() == timeSyncCharUuid) {
            _timeSyncChar = characteristic;
          }
        }
      }
    }
  }

  Future<bool> syncTime() async {
    if (_connectedDevice == null) return false;
    if (_timeSyncChar == null) {
      await _discoverServices();
    }
    if (_timeSyncChar == null) return false;

    final now = DateTime.now();
    // Format: YYYYMMDDHHMMSS
    String year = now.year.toString().padLeft(4, '0');
    String month = now.month.toString().padLeft(2, '0');
    String day = now.day.toString().padLeft(2, '0');
    String hour = now.hour.toString().padLeft(2, '0');
    String minute = now.minute.toString().padLeft(2, '0');
    String second = now.second.toString().padLeft(2, '0');

    String timeStr = '$year$month$day$hour$minute$second';
    await _timeSyncChar!.write(timeStr.codeUnits);
    return true;
  }

  Future<bool> sendCommand(String cmd) async {
    if (_connectedDevice == null) return false;
    if (_commandChar == null) {
      await _discoverServices();
    }
    if (_commandChar == null) return false;

    await _commandChar!.write(cmd.codeUnits);
    return true;
  }

  Future<bool> resetServo() async {
    return sendCommand("RESET");
  }

  Future<bool> addScheduleToDevice(String time, int compartment) async {
    // time format HH:MM -> "ADD:HH:MM:C"
    return sendCommand("ADD:$time:$compartment");
  }

  Future<bool> deleteScheduleFromDevice(String time, int compartment) async {
    // time format HH:MM -> "DEL:HH:MM:C"
    return sendCommand("DEL:$time:$compartment");
  }

  @override
  void dispose() {
    _scanResultsSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    super.dispose();
  }
}
