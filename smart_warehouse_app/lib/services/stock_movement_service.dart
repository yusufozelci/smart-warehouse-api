import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stock_movement_model.dart';

class StockMovementService {
  String get baseUrl => kIsWeb
      ? "http://localhost:8080/api/v1/stock-movements"
      : (Platform.isAndroid ? "http://10.0.2.2:8080/api/v1/stock-movements" : "http://localhost:8080/api/v1/stock-movements");

  Future<List<StockMovementModel>> getMovements() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.get(
      Uri.parse(baseUrl),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token"
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((dynamic item) => StockMovementModel.fromJson(item)).toList().reversed.toList(); // En yeniler üstte
    } else {
      throw Exception('Stok hareketleri yüklenemedi!');
    }
  }
}