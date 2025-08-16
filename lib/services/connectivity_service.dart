// services/connectivity_service.dart
import 'dart:async';
import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

enum ConnectivityStatus {
  connected,
  disconnected,
  unknown,
}

enum NetworkType {
  wifi,
  mobile,
  ethernet,
  none,
}

class ConnectivityInfo {
  final ConnectivityStatus status;
  final NetworkType networkType;
  final bool hasInternetAccess;
  final DateTime lastChecked;

  const ConnectivityInfo({
    required this.status,
    required this.networkType,
    required this.hasInternetAccess,
    required this.lastChecked,
  });

  bool get isConnected => status == ConnectivityStatus.connected && hasInternetAccess;

  @override
  String toString() {
    return 'ConnectivityInfo(status: $status, type: $networkType, internet: $hasInternetAccess)';
  }
}

class ConnectivityController extends GetxController {
  final Connectivity _connectivity = Connectivity();
  final InternetConnection _internetChecker = InternetConnection();

  // Observable connectivity state
  final Rx<ConnectivityInfo> connectivityInfo = ConnectivityInfo(
    status: ConnectivityStatus.unknown,
    networkType: NetworkType.none,
    hasInternetAccess: false,
    lastChecked: DateTime.now(),
  ).obs;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<InternetStatus>? _internetSubscription;
  Timer? _retryTimer;

  // Getters for easy access
  bool get isConnected => connectivityInfo.value.isConnected;
  NetworkType get networkType => connectivityInfo.value.networkType;
  ConnectivityStatus get status => connectivityInfo.value.status;

  @override
  void onInit() {
    super.onInit();
    _initializeConnectivityMonitoring();
  }

  Future<void> _initializeConnectivityMonitoring() async {
    try {
      // Check initial connectivity
      await _checkCurrentConnectivity();

      // Listen to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _onConnectivityChanged,
        onError: (error) {
          print('Connectivity subscription error: $error');
          _handleConnectivityError();
        },
      );

      // Listen to internet status changes
      _internetSubscription = _internetChecker.onStatusChange.listen(
        _onInternetStatusChanged,
        onError: (error) {
          print('Internet connectivity subscription error: $error');
        },
      );

      print('ConnectivityController initialized successfully');
    } catch (e) {
      print('Failed to initialize ConnectivityController: $e');
      _handleConnectivityError();
    }
  }

  Future<void> _checkCurrentConnectivity() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      final hasInternet = await _internetChecker.hasInternetAccess;

      final networkType = _mapConnectivityToNetworkType(connectivityResults);
      final status = _determineConnectivityStatus(connectivityResults, hasInternet);

      connectivityInfo.value = ConnectivityInfo(
        status: status,
        networkType: networkType,
        hasInternetAccess: hasInternet,
        lastChecked: DateTime.now(),
      );
    } catch (e) {
      print('Error checking current connectivity: $e');
      _handleConnectivityError();
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    print('Connectivity changed: $results');
    
    // Debounce rapid connectivity changes
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(milliseconds: 500), () async {
      await _performConnectivityCheck(results);
    });
  }

  void _onInternetStatusChanged(InternetStatus status) async {
    print('Internet status changed: $status');
    
    // Re-check connectivity when internet status changes
    final connectivityResults = await _connectivity.checkConnectivity();
    await _performConnectivityCheck(connectivityResults);
  }

  Future<void> _performConnectivityCheck(List<ConnectivityResult> results) async {
    try {
      final hasInternet = await _internetChecker.hasInternetAccess;
      final networkType = _mapConnectivityToNetworkType(results);
      final status = _determineConnectivityStatus(results, hasInternet);

      connectivityInfo.value = ConnectivityInfo(
        status: status,
        networkType: networkType,
        hasInternetAccess: hasInternet,
        lastChecked: DateTime.now(),
      );

      print('Connectivity state updated: ${connectivityInfo.value}');
    } catch (e) {
      print('Error performing connectivity check: $e');
      _handleConnectivityError();
    }
  }

  NetworkType _mapConnectivityToNetworkType(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi)) {
      return NetworkType.wifi;
    } else if (results.contains(ConnectivityResult.mobile)) {
      return NetworkType.mobile;
    } else if (results.contains(ConnectivityResult.ethernet)) {
      return NetworkType.ethernet;
    } else {
      return NetworkType.none;
    }
  }

  ConnectivityStatus _determineConnectivityStatus(
    List<ConnectivityResult> results,
    bool hasInternet,
  ) {
    if (results.contains(ConnectivityResult.none)) {
      return ConnectivityStatus.disconnected;
    }
    
    if (hasInternet) {
      return ConnectivityStatus.connected;
    } else {
      // Has network interface but no internet access
      return ConnectivityStatus.disconnected;
    }
  }

  void _handleConnectivityError() {
    connectivityInfo.value = ConnectivityInfo(
      status: ConnectivityStatus.unknown,
      networkType: NetworkType.none,
      hasInternetAccess: false,
      lastChecked: DateTime.now(),
    );
  }

  /// Manually refresh connectivity status
  Future<void> refreshConnectivity() async {
    await _checkCurrentConnectivity();
  }

  @override
  void onClose() {
    _retryTimer?.cancel();
    _connectivitySubscription?.cancel();
    _internetSubscription?.cancel();
    super.onClose();
  }
}
