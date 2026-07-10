import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class AuthService {
  String get baseUrl {
    if (kIsWeb) return "http://localhost:8080";
    if (defaultTargetPlatform == TargetPlatform.android) return "http://10.0.2.2:8080";
    return "http://localhost:8080";
  }

  Future<bool> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      String token = responseBody['token'];

      print("--------------------------------------------------");
      print("DEBUG- Login Başarılı. Token:");
      print(token);
      print("--------------------------------------------------");


      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      print("DEBUG - Token içeriği (Okunabilir): $decodedToken");

      int? workerId = responseBody['workerId'] ?? decodedToken['workerId'] ?? decodedToken['id'];

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);

      if (workerId != null) {
        await prefs.setInt('workerId', workerId);
        print("DEBUG - Kaydedilen Worker ID: $workerId");
      } else {
        print("UYARI: workerId bulunamadı! Backend ayarlarını kontrol edin.");
      }

      String workerName = responseBody['name'] ?? decodedToken['name'] ?? decodedToken['sub'] ?? 'Saha Personeli';
      await prefs.setString('workerName', workerName);
      print("DEBUG - Kaydedilen İsim: $workerName");

      String role = decodedToken['role'] ?? 'WORKER';
      await prefs.setString('role', role);
      print("DEBUG - Kaydedilen Rol: $role");

      return true;
    }
    print("DEBUG - Login Başarısız. Status Code: ${response.statusCode}");
    return false;
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<String?> getRole() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }
}