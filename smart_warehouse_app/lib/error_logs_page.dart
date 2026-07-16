import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ErrorLogsPage extends StatefulWidget {
  const ErrorLogsPage({super.key});

  @override
  State<ErrorLogsPage> createState() => _ErrorLogsPageState();
}

class _ErrorLogsPageState extends State<ErrorLogsPage> {
  List<dynamic> _logs = [];
  bool _isLoading = true;

  String get baseUrl => kIsWeb ? "http://localhost:8080" : (Platform.isAndroid ? "http://10.0.2.2:8080" : "http://localhost:8080");

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final headers = {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token"
      };

      final response = await http.get(Uri.parse('$baseUrl/api/admin/logs'), headers: headers);

      if (response.statusCode == 200) {
        setState(() {
          _logs = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sistem Hata Kayıtları", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red.shade800,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : _logs.isEmpty
          ? const Center(child: Text("Harika! Sistemde kayıtlı hiçbir hata yok.", style: TextStyle(fontSize: 16)))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          final log = _logs[index];
          DateTime time = DateTime.parse(log['timestamp']);
          String formattedTime = DateFormat('dd.MM.yyyy - HH:mm:ss').format(time);

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ExpansionTile(
              leading: const Icon(Icons.error_outline, color: Colors.red, size: 30),
              title: Text(log['message'] ?? 'Bilinmeyen Hata', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
              subtitle: Text(formattedTime, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  color: Colors.grey.shade50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Stack Trace (Hata Detayı):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Builder(builder: (context) {
                        String rawTrace = log['stackTrace'] ?? 'Detay yok.';
                        List<String> traceLines = rawTrace
                            .replaceAll('[', '')
                            .replaceAll(']', '')
                            .split(', ');
                        List<String> filteredLines = traceLines
                            .where((line) => line.contains('com.smartwarehouse'))
                            .toList();
                        if (filteredLines.isEmpty) {
                          filteredLines = traceLines.take(3).toList();
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: filteredLines.map((line) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              "👉 ${line.trim()}",
                              style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.w600
                              ),
                            ),
                          )).toList(),
                        );
                      })
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}