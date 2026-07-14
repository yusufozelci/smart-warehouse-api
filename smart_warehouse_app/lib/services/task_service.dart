import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';

class TaskService {
  String get baseUrl => kIsWeb
      ? "http://localhost:8080/api/v1/tasks"
      : (Platform.isAndroid ? "http://10.0.2.2:8080/api/v1/tasks" : "http://localhost:8080/api/v1/tasks");

  Future<List<TaskModel>> getAllTasks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.get(
      Uri.parse(baseUrl),
      headers: {"Content-Type": "application/json", if (token != null) "Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((dynamic item) => TaskModel.fromJson(item)).toList();
    } else {
      throw Exception('Görevler yüklenemedi.');
    }
  }

  Future<bool> createTask(int? workerId, List<Map<String, dynamic>> items) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    Map<String, dynamic> body = {"items": items};
    if (workerId != null) body["assignedWorkerId"] = workerId;

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {"Content-Type": "application/json", if (token != null) "Authorization": "Bearer $token"},
      body: jsonEncode(body),
    );

    return response.statusCode == 201 || response.statusCode == 200;
  }

  Future<bool> assignTaskManually(int taskId, int workerId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.put(
      Uri.parse("$baseUrl/$taskId/assign/$workerId"),
      headers: {"Content-Type": "application/json", if (token != null) "Authorization": "Bearer $token"},
    );

    return response.statusCode == 200;
  }

  Future<bool> assignClosestTask(int currentShelfId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    int? workerId = prefs.getInt('workerId');

    final response = await http.post(
      Uri.parse("$baseUrl/assign-closest?workerId=$workerId&currentShelfId=$currentShelfId"),
      headers: {"Content-Type": "application/json", if (token != null) "Authorization": "Bearer $token"},
    );

    return response.statusCode == 200;
  }

  Future<List<TaskModel>> getTasksForWorker() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    int? workerId = prefs.getInt('workerId');

    if (workerId == null) {
      throw Exception('Hata: Worker ID bulunamadı.');
    }

    final response = await http.get(
      Uri.parse("$baseUrl/worker/$workerId"),
      headers: {"Content-Type": "application/json", if (token != null) "Authorization": "Bearer $token"},
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

      final response = await http.post(
        Uri.parse("$baseUrl/$taskId/pick/$productId"),
        headers: {"Content-Type": "application/json", if (token != null) "Authorization": "Bearer $token"},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> completeTask(int taskId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.put(
        Uri.parse("$baseUrl/$taskId/complete"),
        headers: {"Content-Type": "application/json", if (token != null) "Authorization": "Bearer $token"},
      );
      return response.statusCode == 200;
    } catch (e) {
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
        if (token != null) "Authorization": "Bearer $token"
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