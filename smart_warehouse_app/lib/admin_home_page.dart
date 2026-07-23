import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_warehouse_app/services/auth_service.dart';
import 'package:smart_warehouse_app/login_page.dart';
import 'package:smart_warehouse_app/services/task_service.dart';
import 'package:smart_warehouse_app/services/websocket_service.dart';
import 'package:smart_warehouse_app/global_utils.dart';
import 'package:smart_warehouse_app/stock_statistics_page.dart';
import 'package:smart_warehouse_app/worker_management_page.dart';
import 'cancelled_task_page.dart';
import 'inventory_page.dart';
import 'operation_statistics_page.dart';
import 'product_catalog_page.dart';
import 'warehouse_map_page.dart';
import 'completed_tasks_page.dart';
import 'error_logs_page.dart';
import 'statistics_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _selectedIndex = 0;
  List<Map<String, dynamic>> _liveUpdates = [];
  int _totalProducts = 0;
  int _activeWorkers = 0;
  int _completedTasks = 0;
  int _cancelledTasksCount = 0;
  int _errorLogs = 0;
  bool _isLoadingStats = true;

  String get baseUrl => kIsWeb ? "http://localhost:8080" : (Platform.isAndroid ? "http://10.0.2.2:8080" : "http://localhost:8080");

  @override
  void initState() {
    super.initState();
    String wsUrl = baseUrl.replaceAll("http://", "ws://") + "/ws-warehouse";
    WebSocketService.instance.connect(wsUrl);
    _fetchStats();
    _liveUpdates = List.from(WebSocketService.instance.messages);
    WebSocketService.instance.subscribe(_onTaskReceived);
    WebSocketService.instance.subscribeToErrors((data) {
      if (mounted) {
        setState(() {
          _errorLogs++;
        });
      }
    });
  }

  void _onTaskReceived(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      _liveUpdates.insert(0, data);
      if(data['status'] == 'COMPLETED') _completedTasks++;
    });
    showGlobalNotification("Yeni İşlem: ${data['message'] ?? 'Ürün okutuldu'}");
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final headers = {"Content-Type": "application/json", if (token != null) "Authorization": "Bearer $token"};
      final response = await http.get(Uri.parse('$baseUrl/api/admin/stats'), headers: headers);
      final workerResponse = await http.get(Uri.parse('$baseUrl/api/v1/workers'), headers: headers);
      final deletedTasks = await TaskService().getDeletedTasks();

      if (!mounted) return;

      if (response.statusCode == 200 && workerResponse.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> allWorkers = jsonDecode(workerResponse.body);

        setState(() {
          _totalProducts = data['totalProducts'] ?? 0;
          _activeWorkers = allWorkers.where((w) => w['role'] == 'WORKER').length;
          _completedTasks = data['completedTasks'] ?? 0;
          _cancelledTasksCount = deletedTasks.length;

          _errorLogs = data['errorLogs'] ?? 0;
          _isLoadingStats = false;
        });
      } else {
        setState(() => _isLoadingStats = false);
      }
    } catch (e) {
      debugPrint("İstatistikler yüklenirken hata: $e");
      if (!mounted) return;
      setState(() => _isLoadingStats = false);
    }
  }

  @override
  void dispose() {
    WebSocketService.instance.unsubscribe(_onTaskReceived);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF9FAFB),
      drawer: isDesktop ? null : _buildSidebar(isDesktop: false),
      body: SafeArea(
        child: Row(
          children: [
            if (isDesktop) _buildSidebar(isDesktop: true),
            Expanded(
              child: Column(
                children: [
                  _buildHeader(isDesktop),
                  Expanded(child: _buildCurrentPage(isDesktop)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar({required bool isDesktop}) {
    return Container(
      width: 250,
      color: const Color(0xFF111827),
      child: Column(
        children: [
          const SizedBox(height: 30),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.analytics, color: Colors.white, size: 28),
                SizedBox(width: 10),
                Text("Akıllı Depo", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 40),
          _buildMenuTile(0, "Genel Durum", Icons.dashboard_outlined),
          _buildMenuTile(1, "Personeller", Icons.people_outline),
          _buildMenuTile(2, "Stok Yönetimi", Icons.inventory_2_outlined),
          _buildMenuTile(3, "Görev & Rotalar", Icons.map_outlined),
          _buildMenuTile(4, "Operasyon İstatistiği", Icons.insert_chart_outlined),
          _buildMenuTile(5, "Stok İstatistiği", Icons.insights),
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.white70),
              title: const Text("Çıkış Yap", style: TextStyle(color: Colors.white70)),
              onTap: () async {
                await AuthService().logout();
                if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMenuTile(int index, String title, IconData icon) {
    final bool isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Material(
        color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() => _selectedIndex = index);
            if (MediaQuery.of(context).size.width <= 800) {
              Navigator.pop(context);
            }
          },
          child: ListTile(
            leading: Icon(icon, color: isSelected ? Colors.white : Colors.white60),
            title: Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 12, vertical: 16),
      color: Colors.white,
      child: Row(
        children: [
          if (!isDesktop)
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.black87),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),

          Text(isDesktop ? "Warehouse Management" : "Dashboard", style: TextStyle(fontSize: isDesktop ? 22 : 18, fontWeight: FontWeight.bold)),
          const Spacer(),

          if (isDesktop)
            Container(
              width: 200,
              height: 40,
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: const TextField(decoration: InputDecoration(prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey), border: InputBorder.none, hintText: "Search")),
            ),
          if (isDesktop) const SizedBox(width: 20),

          const CircleAvatar(
            backgroundColor: Color(0xFF111827),
            radius: 18,
            child: Text("YÖ", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),

          if (isDesktop) const SizedBox(width: 10),
          if (isDesktop) const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Yusuf Özelci", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text("Admin", style: TextStyle(color: Colors.green, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPage(bool isDesktop) {
    switch (_selectedIndex) {
      case 0: return _buildDashboardScreen(isDesktop);
      case 1: return const WorkerManagementPage(initialFilter: "ALL");
      case 2: return const InventoryPage();
      case 3: return const WarehouseMapPage(isDashboard: false);
      case 4: return const OperationStatisticsPage();
      case 5: return const StockStatisticsPage();
      default: return _buildDashboardScreen(isDesktop);
    }
  }

  Widget _buildDashboardScreen(bool isDesktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          if (isDesktop)
            Center(
              child: Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: _buildStatCards(),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _buildStatCards().map((card) => Padding(padding: const EdgeInsets.only(right: 16), child: card)).toList(),
              ),
            ),

          const SizedBox(height: 30),

          if (isDesktop) ...[
            Container(
              height: 360,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                  ]
              ),
              child: const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                child: WarehouseMapPage(isDashboard: true),
              ),
            ),
            const SizedBox(height: 30),
          ],

          const Text("Canlı Saha Akışı", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Container(
            height: isDesktop ? 350 : MediaQuery.of(context).size.height * 0.65,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: _liveUpdates.isEmpty
                ? Center(child: Text("Saha personelinden işlem bekleniyor...", style: TextStyle(color: Colors.grey.shade500)))
                : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _liveUpdates.length,
              separatorBuilder: (_, __) => Divider(color: Colors.grey.shade100),
              itemBuilder: (context, index) {
                final update = _liveUpdates[index];
                return ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.green, radius: 15, child: Icon(Icons.flash_on, color: Colors.white, size: 15)),
                  title: Text(update['message'] ?? "İşlem", style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text("Görev ID: ${update['taskId'] ?? '-'}"),
                  trailing: const Text("Şimdi", style: TextStyle(color: Colors.grey, fontSize: 12)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStatCards() {
    return [
      _buildModernStatCard("Toplam Ürün", "$_totalProducts", Icons.inventory_2, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductCatalogPage()))),
      _buildModernStatCard("Aktif Personel", "$_activeWorkers", Icons.people, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkerManagementPage(initialFilter: "ACTIVE_ONLY")))),
      _buildModernStatCard("Tamamlanan", "$_completedTasks", Icons.check_circle, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompletedTasksPage()))),
      _buildModernStatCard("İptal Edilen", "$_cancelledTasksCount", Icons.cancel, Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CancelledTasksPage()))),
      _buildModernStatCard("Hata Kaydı", "$_errorLogs", Icons.error, Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ErrorLogsPage()))),
    ];
  }

  Widget _buildModernStatCard(String title, String value, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}