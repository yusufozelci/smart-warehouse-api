import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../main.dart';

class WebSocketService {
  static final WebSocketService instance = WebSocketService._internal();
  factory WebSocketService() => instance;
  WebSocketService._internal();

  StompClient? stompClient;

  List<Map<String, dynamic>> messages = [];
  final List<Function(Map<String, dynamic>)> _listeners = [];

  void connect(String url) {
    if (stompClient != null && stompClient!.connected) return;

    stompClient = StompClient(
      config: StompConfig(
        url: url,
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
        reconnectDelay: const Duration(seconds: 5),
        onConnect: (frame) {
          print("Global WebSocket: Bağlantı Başarılı!");
          stompClient!.subscribe(
            destination: '/topic/manager/tasks',
            callback: (frame) {
              if (frame.body != null) {
                final Map<String, dynamic> data = json.decode(frame.body!);
                for (var listener in _listeners) {
                  listener(data);
                }
              }
            },
          );
        },
      ),
    );
    stompClient!.activate();
  }

  void subscribe(Function(Map<String, dynamic>) listener) {
    _listeners.add(listener);
  }

  void unsubscribe(Function(Map<String, dynamic>) listener) {
    _listeners.remove(listener);
  }
}