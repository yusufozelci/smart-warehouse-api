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

      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);

      int? workerId = responseBody['workerId'] ?? decodedToken['workerId'] ?? decodedToken['id'];
      if (workerId != null) {
        await prefs.setInt('workerId', workerId);
      }
      String? fName = responseBody['firstName'] ?? decodedToken['firstName'];
      String? lName = responseBody['lastName'] ?? decodedToken['lastName'];
      if (fName == null && lName == null) {
        String? fullName = responseBody['name'] ?? decodedToken['name'];
        if (fullName != null && fullName.contains(' ')) {
          List<String> parts = fullName.split(' ');
          fName = parts.first;
          lName = parts.sublist(1).join(' ');
        } else if (fullName != null) {
          fName = fullName;
          lName = "";
        }
      }
      await prefs.setString('firstName', fName ?? 'Bilinmeyen');
      await prefs.setString('lastName', lName ?? 'Kullanıcı');

      print("DEBUG - Giriş Yapan Kişi: $fName $lName");

      String role = decodedToken['role'] ?? 'WORKER';
      await prefs.setString('role', role);

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