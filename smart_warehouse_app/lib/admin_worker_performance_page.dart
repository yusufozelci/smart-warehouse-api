import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:smart_warehouse_app/widgets/performances/performance_dashboard_widget.dart';

import 'models/worker_performance_model.dart';
import 'services/performance_service.dart';
import 'widgets/performances/performance_dashboard_widget.dart';

class AdminWorkerPerformancePage extends StatefulWidget {
  const AdminWorkerPerformancePage({super.key});

  @override
  State<AdminWorkerPerformancePage> createState() => _AdminWorkerPerformancePageState();
}

class _AdminWorkerPerformancePageState extends State<AdminWorkerPerformancePage> {
  List<dynamic> _workers = [];
  int? _selectedWorkerId;
  WorkerPerformanceModel? _performanceData;
  bool _isLoading = false;

  String get baseUrl => kIsWeb ? "http://localhost:8080" : (Platform.isAndroid ? "http://10.0.2.2:8080" : "http://localhost:8080");

  @override
  void initState() {
    super.initState();
    _fetchWorkers();
  }

  Future<void> _fetchWorkers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/workers'),
      headers: {"Content-Type": "application/json", if (token != null) "Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      List<dynamic> allWorkers = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        _workers = allWorkers.where((w) => w['role'] == 'WORKER').toList();
      });
    }
  }

  Future<void> _fetchPerformance(int workerId) async {
    setState(() => _isLoading = true);
    try {
      final data = await PerformanceService().getWorkerPerformance(workerId);
      setState(() => _performanceData = data);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Personel Performans Analizi", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedWorkerId,
                hint: const Text("Performansını görmek istediğiniz personeli seçin"),
                isExpanded: true,
                items: _workers.map((w) => DropdownMenuItem<int>(
                  value: w['id'],
                  child: Text("${w['firstName']} ${w['lastName']}"),
                )).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedWorkerId = val);
                    _fetchPerformance(val);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 30),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_performanceData != null)
            PerformanceDashboardWidget(data: _performanceData!)
          else
            Center(child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Text("Veri görüntülemek için bir personel seçin.", style: TextStyle(color: Colors.grey.shade500)),
            )),
        ],
      ),
    );
  }
}