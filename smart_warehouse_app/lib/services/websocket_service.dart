import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

class WebSocketService {
  static final WebSocketService instance = WebSocketService._internal();
  factory WebSocketService() => instance;
  WebSocketService._internal();

  StompClient? stompClient;

  List<Map<String, dynamic>> messages = [];
  final List<Function(Map<String, dynamic>)> _listeners = [];
  final List<Function(Map<String, dynamic>)> _errorListeners = [];

  void connect(String url) {
    if (stompClient != null && stompClient!.connected) return;

    stompClient = StompClient(
      config: StompConfig(
        url: url,
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
        reconnectDelay: const Duration(seconds: 5),
        onConnect: (frame) {
          debugPrint("✅ Global WebSocket: Bağlantı Başarılı!");

          stompClient!.subscribe(
            destination: '/topic/manager/tasks',
            callback: (frame) {
              debugPrint("📩 [MANAGER TASKS] Yeni mesaj geldi: ${frame.body}");
              if (frame.body != null) {
                Map<String, dynamic> data = {};
                try {
                  data = json.decode(frame.body!);
                } catch (e) {
                  debugPrint("⚠️ JSON Çevirme Hatası (Düz metin olarak kabul edilecek): $e");
                  data = {"message": frame.body};
                }

                debugPrint("🚀 ${_listeners.length} adet sekmeye/sayfaya yenileme sinyali gönderiliyor...");
                for (var listener in _listeners) {
                  listener(data);
                }
              }
            },
          );

          stompClient!.subscribe(
            destination: '/topic/admin/errors',
            callback: (frame) {
              if (frame.body != null) {
                Map<String, dynamic> data = {};
                try {
                  data = json.decode(frame.body!);
                } catch (e) {
                  data = {"message": frame.body};
                }

                for (var listener in _errorListeners) {
                  listener(data);
                }
              }
            },
          );
        },
        onWebSocketError: (dynamic error) => debugPrint("❌ WebSocket Hatası: $error"),
        onStompError: (frame) => debugPrint("❌ Stomp Hatası: ${frame.body}"),
        onDisconnect: (frame) => debugPrint("⚠️ WebSocket Koptu, yeniden bağlanılacak..."),
      ),
    );
    stompClient!.activate();
  }

  void subscribe(Function(Map<String, dynamic>) listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
      debugPrint("✅ Yeni sayfa WebSocket'e abone oldu. (Toplam Dinleyici: ${_listeners.length})");
    }
  }

  void unsubscribe(Function(Map<String, dynamic>) listener) {
    _listeners.remove(listener);
    debugPrint("🗑️ Bir sayfa WebSocket aboneliğinden çıktı. (Kalan Dinleyici: ${_listeners.length})");
  }

  void subscribeToErrors(Function(Map<String, dynamic>) listener) {
    if (!_errorListeners.contains(listener)) {
      _errorListeners.add(listener);
    }
  }

  void unsubscribeFromErrors(Function(Map<String, dynamic>) listener) {
    _errorListeners.remove(listener);
  }
}