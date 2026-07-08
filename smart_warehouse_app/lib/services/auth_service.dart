import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class AuthService {
  final String baseUrl = "http://10.0.2.2:8080/api/auth";

  Future<bool> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    if (response.statusCode == 200) {
      String token = jsonDecode(response.body)['token'];

      // Token içeriğini kontrol etme
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      print("DEBUG - Token içeriği: $decodedToken");

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);

      String role = decodedToken['role'] ?? 'WORKER';
      await prefs.setString('role', role);
      print("DEBUG - Kaydedilen Rol: $role");

      return true;
    }
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