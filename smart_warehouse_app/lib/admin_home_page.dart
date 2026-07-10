import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_warehouse_app/services/auth_service.dart';
import 'package:smart_warehouse_app/login_page.dart';
import 'package:smart_warehouse_app/services/websocket_service.dart';
import 'package:smart_warehouse_app/global_utils.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  List<Map<String, dynamic>> _liveUpdates = [];

  int _totalProducts = 0;
  int _activeWorkers = 0;
  int _completedTasks = 0;
  int _errorLogs = 0;
  bool _isLoadingStats = true;

  String get baseUrl {
    if (kIsWeb) return "http://localhost:8080";
    if (Platform.isAndroid) return "http://10.0.2.2:8080";
    return "http://localhost:8080";
  }

  String get wsBaseUrl {
    if (kIsWeb) return "ws://localhost:8080";
    if (Platform.isAndroid) return "ws://10.0.2.2:8080";
    return "ws://localhost:8080";
  }

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _liveUpdates = List.from(WebSocketService.instance.messages);
    WebSocketService.instance.subscribe(_onTaskReceived);
  }
  void _onTaskReceived(Map<String, dynamic> data) {
    if (mounted) {
      setState(() {
        _liveUpdates.insert(0, data);
        _completedTasks++;
      });
      showGlobalNotification("Yeni İşlem: ${data['message'] ?? 'Ürün okutuldu'}");
    }
  }

  Future<void> _fetchStats() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/stats'),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token"
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _totalProducts = data['totalProducts'] ?? 0;
          _activeWorkers = data['activeWorkers'] ?? 0;
          _completedTasks = data['completedTasks'] ?? 0;
          _errorLogs = data['errorLogs'] ?? 0;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      print("İstatistikler çekilemedi: $e");
      setState(() => _isLoadingStats = false);
    }
  }

  void _showNotification(Map<String, dynamic> data) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text("Yeni İşlem: ${data['message'] ?? 'Ürün okutuldu'}")),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    WebSocketService.instance.unsubscribe(_onTaskReceived);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Yönetici Paneli"),
        backgroundColor: Colors.redAccent,
        actions: [
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await AuthService().logout();
                if (mounted) {
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => LoginPage())
                  );
                }
              }
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: _isLoadingStats
                ? const Center(child: CircularProgressIndicator())
                : GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(20),
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              children: [
                _buildStatCard("Toplam Ürün", "$_totalProducts", Icons.inventory, Colors.orange),
                _buildStatCard("Aktif Personel", "$_activeWorkers", Icons.people, Colors.blue),
                _buildStatCard("Tamamlanan Görev", "$_completedTasks", Icons.check_circle, Colors.green),
                _buildStatCard("Hata Kaydı", "$_errorLogs", Icons.error, Colors.red),
              ],
            ),
          ),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: Colors.grey.shade200,
            child: const Text(
              "Canlı Saha Akışı",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),

          Expanded(
            flex: 5,
            child: _liveUpdates.isEmpty
                ? Center(
              child: Text(
                "Saha personelinden işlem bekleniyor...",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _liveUpdates.length,
              itemBuilder: (context, index) {
                final update = _liveUpdates[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.flash_on, color: Colors.white),
                    ),
                    title: Text(
                      update['message'] ?? "İşlem Başarılı",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text("Kutu: ${update['boxId'] ?? '-'} | Personel: ${update['workerId'] ?? '-'}"),
                    trailing: const Text(
                      "Şimdi",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}