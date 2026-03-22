import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  final StreamController<bool> _connectionStatusController =
  StreamController<bool>.broadcast();

  Stream<bool> get connectionStream => _connectionStatusController.stream;
  bool _isConnected = true;
  bool get isConnected => _isConnected;

  ConnectivityService() {
    _init();
  }

  void _init() {
    checkConnectivity();
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      final connected = result != ConnectivityResult.none;
      _isConnected = connected;
      _connectionStatusController.add(connected);
    });
  }

  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isConnected = result != ConnectivityResult.none;
      return _isConnected;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  Future<bool> isWifiConnected() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result == ConnectivityResult.wifi;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isMobileDataConnected() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result == ConnectivityResult.mobile;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _connectionStatusController.close();
  }
}