import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';

class TaskService {
  final String baseUrl = "http://10.0.2.2:8080/api/v1/tasks";

  Future<List<TaskModel>> getTasksForWorker() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    int? workerId = prefs.getInt('workerId');

    print("DEBUG: Gönderilen Worker ID: $workerId");
    if (workerId == null) {
      throw Exception('Hata: Worker ID bulunamadı. Lütfen tekrar giriş yapın.');
    }

    final response = await http.get(
      Uri.parse("$baseUrl/worker/$workerId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );

    print("DEBUG: Response Status Code: ${response.statusCode}");
    print("DEBUG: Response Body: ${response.body}");

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((dynamic item) => TaskModel.fromJson(item)).toList();
    } else {
      throw Exception('Görevler yüklenemedi. Durum Kodu: ${response.statusCode} - Hata: ${response.body}');
    }
  }

  Future<bool> completeTask(int taskId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      if (token == null) {
        print("DEBUG: Token bulunamadı, yetkisiz işlem!");
        return false;
      }

      final response = await http.put(
        Uri.parse("$baseUrl/$taskId/complete"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
      );

      print("DEBUG: Complete Task Status Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        return true;
      } else {
        print("DEBUG: Complete Task Error: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Görev tamamlama bağlantı hatası: $e");
      return false;
    }
  }
  Future<List<TaskModel>> getCompletedTasksForWorker() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    int? workerId = prefs.getInt('workerId');

    if (workerId == null) {
      throw Exception('Hata: Worker ID bulunamadı.');
    }

    final response = await http.get(
      Uri.parse("$baseUrl/worker/$workerId/completed"), // Yeni endpoint
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((dynamic item) => TaskModel.fromJson(item)).toList();
    } else {
      throw Exception('Geçmiş görevler yüklenemedi.');
    }
  }
}