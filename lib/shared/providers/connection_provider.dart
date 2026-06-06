import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

enum ConnectionStatus { disconnected, connecting, connected }

class ConnectionStateData {
  final ConnectionStatus status;
  final String? ipAddress;
  final String? serverName;
  final String? error;
  final int barcodesSent;
  final int imagesSent;
  final int invoicesSent;
  final Map<String, dynamic>? lastScannedProduct;

  ConnectionStateData({
    required this.status,
    this.ipAddress,
    this.serverName,
    this.error,
    this.barcodesSent = 0,
    this.imagesSent = 0,
    this.invoicesSent = 0,
    this.lastScannedProduct,
  });

  ConnectionStateData copyWith({
    ConnectionStatus? status,
    String? ipAddress,
    String? serverName,
    String? error,
    int? barcodesSent,
    int? imagesSent,
    int? invoicesSent,
    Map<String, dynamic>? lastScannedProduct,
    bool clearError = false,
  }) {
    return ConnectionStateData(
      status: status ?? this.status,
      ipAddress: ipAddress ?? this.ipAddress,
      serverName: serverName ?? this.serverName,
      error: clearError ? null : (error ?? this.error),
      barcodesSent: barcodesSent ?? this.barcodesSent,
      imagesSent: imagesSent ?? this.imagesSent,
      invoicesSent: invoicesSent ?? this.invoicesSent,
      lastScannedProduct: lastScannedProduct ?? this.lastScannedProduct,
    );
  }
}

class ConnectionNotifier extends Notifier<ConnectionStateData> {
  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  StreamSubscription? _connectivitySubscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _explicitDisconnect = false;
  RawDatagramSocket? _udpSocket;

  static const String _ipPrefKey = 'ykms_server_ip';

  @override
  ConnectionStateData build() {
    ref.onDispose(() {
      _reconnectTimer?.cancel();
      _pingTimer?.cancel();
      _channelSubscription?.cancel();
      _connectivitySubscription?.cancel();
      _channel?.sink.close();
      _udpSocket?.close();
    });

    Future.microtask(() {
      _loadSavedIp();
      _setupConnectivityMonitoring();
      startUdpDiscovery();
    });

    return ConnectionStateData(status: ConnectionStatus.disconnected);
  }

  Future<void> _loadSavedIp() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString(_ipPrefKey);
    if (savedIp != null && savedIp.isNotEmpty) {
      state = state.copyWith(ipAddress: savedIp);
      // Auto-connect on startup if IP is saved
      connect(savedIp);
    }
  }

  void _setupConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final hasWifiOrEthernet = results.contains(ConnectivityResult.wifi) || 
                               results.contains(ConnectivityResult.ethernet);
      if (!hasWifiOrEthernet && state.status == ConnectionStatus.connected) {
        _handleDisconnect("تم قطع الاتصال بالشبكة المحلية");
      } else if (hasWifiOrEthernet && 
                 state.status == ConnectionStatus.disconnected && 
                 state.ipAddress != null && 
                 !_explicitDisconnect) {
        // Try auto-reconnect if we have a saved IP and network becomes available
        connect(state.ipAddress!);
      }
    });
  }

  Future<bool> connect(String ip) async {
    stopUdpDiscovery();
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _channelSubscription?.cancel();
    await _channel?.sink.close();

    _explicitDisconnect = false;
    state = state.copyWith(status: ConnectionStatus.connecting, ipAddress: ip, clearError: true);

    final wsUrl = 'ws://$ip:8765';
    try {
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel = channel;

      _channelSubscription = channel.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (err) {
          _handleDisconnect("خطأ في الاتصال: $err");
        },
        onDone: () {
          _handleDisconnect("انقطع اتصال الخادم");
        },
      );

      // Send initial check-in/handshake packet
      send({
        'type': 'CHECK_IN',
        'data': {
          'device': 'Android Companion App',
        }
      });

      // Wait 3 seconds to verify handshake receipt (connected status update)
      await Future.delayed(const Duration(seconds: 3));
      
      if (state.status == ConnectionStatus.connecting) {
        // If we haven't switched to connected, let's treat it as success if no error was raised
        state = state.copyWith(status: ConnectionStatus.connected, serverName: "YKMS ERP");
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_ipPrefKey, ip);
        _startPingCycle();
      }

      return state.status == ConnectionStatus.connected;
    } catch (e) {
      _handleDisconnect("تعذر الاتصال بـ $wsUrl: $e");
      return false;
    }
  }

  void disconnect() async {
    _explicitDisconnect = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _channelSubscription?.cancel();
    await _channel?.sink.close();
    stopUdpDiscovery();
    state = state.copyWith(status: ConnectionStatus.disconnected, clearError: true);
  }

  void _handleMessage(dynamic messageStr) {
    try {
      final Map<String, dynamic> msg = jsonDecode(messageStr as String);
      final String type = msg['type'] ?? '';
      final Map<String, dynamic> data = msg['data'] ?? {};

      switch (type) {
        case 'CONNECTION_ACK':
          state = state.copyWith(
            status: ConnectionStatus.connected,
            serverName: data['server_name'] ?? 'YKMS ERP',
          );
          _saveIpToPrefs();
          _startPingCycle();
          break;

        case 'BARCODE_ACK':
          final bool found = data['found'] ?? false;
          final String name = data['name'] ?? 'منتج غير معروف';
          final double? price = data['price'] != null ? (data['price'] as num).toDouble() : null;
          final int? quantity = data['quantity'] != null ? (data['quantity'] as num).toInt() : null;

          state = state.copyWith(
            barcodesSent: state.barcodesSent + 1,
            lastScannedProduct: {
              'found': found,
              'name': name,
              'price': price,
              'quantity': quantity,
              'barcode': data['barcode'] ?? '',
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
          break;

        case 'PING':
          // Respond to ping
          send({'type': 'PONG', 'data': {}});
          break;
      }
    } catch (e) {
      debugPrint("Failed to decode message: $e");
    }
  }

  void _saveIpToPrefs() async {
    if (state.ipAddress != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ipPrefKey, state.ipAddress!);
    }
  }

  void _handleDisconnect(String message) {
    _pingTimer?.cancel();
    if (state.status == ConnectionStatus.connected) {
      state = state.copyWith(status: ConnectionStatus.disconnected, error: message);
      // Auto-reconnect if not explicitly disconnected
      if (!_explicitDisconnect && state.ipAddress != null) {
        _reconnectTimer = Timer(const Duration(seconds: 5), () {
          if (state.ipAddress != null) connect(state.ipAddress!);
        });
      }
      if (!_explicitDisconnect) {
        startUdpDiscovery();
      }
    } else if (state.status == ConnectionStatus.connecting) {
      state = state.copyWith(status: ConnectionStatus.disconnected, error: message);
      if (!_explicitDisconnect) {
        startUdpDiscovery();
      }
    }
  }

  void _startPingCycle() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (state.status == ConnectionStatus.connected) {
        send({'type': 'PING', 'data': {}});
      }
    });
  }

  bool send(Map<String, dynamic> payload) {
    if (_channel == null || state.status == ConnectionStatus.disconnected) {
      return false;
    }
    try {
      _channel!.sink.add(jsonEncode(payload));
      return true;
    } catch (e) {
      debugPrint("WS Send Error: $e");
      return false;
    }
  }

  bool sendBarcode(String barcode) {
    return send({
      'type': 'BARCODE_SCAN',
      'data': {
        'barcode': barcode,
      }
    });
  }

  void incrementImagesSent() {
    state = state.copyWith(imagesSent: state.imagesSent + 1);
  }

  void incrementInvoicesSent() {
    state = state.copyWith(invoicesSent: state.invoicesSent + 1);
  }

  void startUdpDiscovery() async {
    if (_udpSocket != null) return;
    try {
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        8769,
        reuseAddress: true,
        reusePort: true,
      );
      _udpSocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final Datagram? dg = _udpSocket!.receive();
          if (dg != null) {
            try {
              final String data = utf8.decode(dg.data);
              final Map<String, dynamic> payload = jsonDecode(data);
              if (payload['serverName'] == 'YKMS ERP' && payload['ip'] != null) {
                final discoveredIp = payload['ip'] as String;
                // Only auto-connect if we are currently disconnected
                if (state.status == ConnectionStatus.disconnected) {
                  debugPrint("[ConnectionProvider] Auto-discovered YKMS ERP server at: $discoveredIp");
                  connect(discoveredIp);
                }
              }
            } catch (e) {
              // Ignore decode exceptions
            }
          }
        }
      });
      debugPrint("[ConnectionProvider] Started UDP Discovery on port 8769");
    } catch (e) {
      debugPrint("[ConnectionProvider] Failed to start UDP Discovery: $e");
    }
  }

  void stopUdpDiscovery() {
    if (_udpSocket != null) {
      _udpSocket!.close();
      _udpSocket = null;
      debugPrint("[ConnectionProvider] Stopped UDP Discovery");
    }
  }
}

final connectionProvider = NotifierProvider<ConnectionNotifier, ConnectionStateData>(() {
  return ConnectionNotifier();
});
