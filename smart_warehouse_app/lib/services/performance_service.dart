import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/worker_performance_model.dart';

class PerformanceService {
  String get baseUrl => kIsWeb
      ? "http://localhost:8080/api/v1/performance"
      : (Platform.isAndroid ? "http://10.0.2.2:8080/api/v1/performance" : "http://localhost:8080/api/v1/performance");

  Future<WorkerPerformanceModel> getWorkerPerformance(int workerId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.get(
      Uri.parse("$baseUrl/worker/$workerId"),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token"
      },
    );

    if (response.statusCode == 200) {
      return WorkerPerformanceModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('Performans verileri alınamadı.');
    }
  }
}