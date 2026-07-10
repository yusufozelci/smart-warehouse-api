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

    if (workerId == null) {
      throw Exception('Hata: Worker ID bulunamadı.');
    }

    final response = await http.get(
      Uri.parse("$baseUrl/worker/$workerId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((dynamic item) => TaskModel.fromJson(item)).toList();
    } else {
      throw Exception('Görevler yüklenemedi.');
    }
  }

  Future<bool> pickItem(int taskId, int productId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      if (token == null) return false;
      final response = await http.post(
        Uri.parse("$baseUrl/$taskId/pick/$productId"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
      );

      print("DEBUG: Pick Item Status Code: ${response.statusCode}");

      return response.statusCode == 200;
    } catch (e) {
      print("Ürün toplama bağlantı hatası: $e");
      return false;
    }
  }

  Future<bool> completeTask(int taskId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      if (token == null) return false;

      final response = await http.put(
        Uri.parse("$baseUrl/$taskId/complete"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Görev tamamlama hatası: $e");
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
      Uri.parse("$baseUrl/worker/$workerId/completed"),
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