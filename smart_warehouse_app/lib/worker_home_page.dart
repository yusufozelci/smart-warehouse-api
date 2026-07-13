import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_warehouse_app/qr_scanner_page.dart';
import 'package:smart_warehouse_app/services/auth_service.dart';
import 'package:smart_warehouse_app/services/task_service.dart';
import 'package:smart_warehouse_app/models/task_model.dart';
import 'package:smart_warehouse_app/login_page.dart';
import 'package:smart_warehouse_app/global_utils.dart';

class WorkerHomePage extends StatefulWidget {
  const WorkerHomePage({super.key});

  @override
  State<WorkerHomePage> createState() => _WorkerHomePageState();
}

class _WorkerHomePageState extends State<WorkerHomePage> {
  int _currentIndex = 0;
  final Color primaryColor = const Color(0xFF1A237E);

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          ["Aktif Depo Görevleri", "Görev Geçmişi", "Personel Profili"][_currentIndex],
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: [
        const _ActiveTasksTab(),
        const _CompletedTasksTab(),
        const _ProfileTab(),
      ][_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -3))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey.shade500,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Aktif'),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Geçmiş'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      ),
    );
  }
}

class _ActiveTasksTab extends StatefulWidget {
  const _ActiveTasksTab();

  @override
  State<_ActiveTasksTab> createState() => _ActiveTasksTabState();
}

class _ActiveTasksTabState extends State<_ActiveTasksTab> {
  late Future<List<TaskModel>> _tasksFuture;
  final Color primaryColor = const Color(0xFF1A237E);

  String get baseUrl {
    if (kIsWeb) return "http://localhost:8080";
    if (Platform.isAndroid) return "http://10.0.2.2:8080";
    return "http://localhost:8080";
  }

  @override
  void initState() {
    super.initState();
    _refreshTasks();
  }

  void _refreshTasks() {
    setState(() {
      _tasksFuture = TaskService().getTasksForWorker();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TaskModel>>(
      future: _tasksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: primaryColor));
        if (snapshot.hasError) return Center(child: Text("Hata: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text("Bekleyen görev yok.", style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
              ],
            ),
          );
        }

        final tasks = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.assignment_turned_in, color: primaryColor),
                ),
                title: Text("Görev ID: #${task.id}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text("Durum: ${task.status}", style: TextStyle(color: Colors.grey.shade700)),
                ),
                trailing: Icon(Icons.arrow_forward_ios, color: primaryColor, size: 18),
                onTap: () => _showTaskDetails(context, task),
              ),
            );
          },
        );
      },
    );
  }

  void _showTaskDetails(BuildContext context, TaskModel task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                  Text("Görev (#${task.id}) Ürünleri", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor)),
                  const SizedBox(height: 20),
                  ...task.items.map((item) {
                    bool isPicked = item['isPicked'] == true;
                    int requestedQty = item['quantity'] ?? 1;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                      child: ListTile(
                        leading: Icon(Icons.qr_code_scanner, color: isPicked ? Colors.green : Colors.grey.shade500),
                        title: Text(item['productName'] ?? 'Ürün', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("SKU: ${item['sku']}"),
                              const SizedBox(height: 4),
                              Text(
                                  "İstenen Adet: $requestedQty",
                                  style: TextStyle(
                                      color: isPicked ? Colors.green : Colors.red.shade700,
                                      fontWeight: FontWeight.bold
                                  )
                              ),
                            ],
                          ),
                        ),
                        trailing: isPicked
                            ? const Icon(Icons.check_circle, color: Colors.green, size: 30)
                            : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () async {
                            final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => QrScannerPage(expectedSku: item['sku'])));

                            if (result == true) {
                              bool success = await TaskService().pickItem(task.id, item['productId']);

                              if (success) {
                                try {
                                  SharedPreferences prefs = await SharedPreferences.getInstance();
                                  String? token = prefs.getString('token');

                                  final response = await http.put(
                                    Uri.parse('$baseUrl/api/v1/products/${item['productId']}/decrease?amount=$requestedQty'),
                                    headers: {
                                      "Content-Type": "application/json",
                                      if (token != null) "Authorization": "Bearer $token"
                                    },
                                  );

                                  if (response.statusCode == 200) {
                                    setModalState(() { item['isPicked'] = true; });
                                    _refreshTasks();
                                    showGlobalNotification("Ürün okundu ve stoktan $requestedQty adet düşüldü!");
                                  } else {
                                    showGlobalNotification("Hata: ${response.body}");
                                  }
                                } catch (e) {
                                  showGlobalNotification("Bağlantı hatası: $e");
                                }
                              }
                            }
                          },
                          child: const Text("Tara"),
                        ),
                      ),
                    );
                  }),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CompletedTasksTab extends StatelessWidget {
  const _CompletedTasksTab();
  final Color primaryColor = const Color(0xFF1A237E);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TaskModel>>(
      future: TaskService().getCompletedTasksForWorker(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: primaryColor));
        final tasks = snapshot.data!;
        tasks.sort((a, b) => b.id.compareTo(a.id));

        if (tasks.isEmpty) {
          return Center(
            child: Text("Henüz tamamlanmış görev yok.", style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle, color: Colors.green, size: 28),
                ),
                title: Text("Görev ID: #${task.id}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 5.0),
                  child: Text("Toplam ${task.items.length} ürün toplandı.", style: TextStyle(color: Colors.grey.shade600)),
                ),
                trailing: Icon(Icons.visibility, color: Colors.grey.shade400),
                onTap: () => _showReadOnlyDetails(context, task),
              ),
            );
          },
        );
      },
    );
  }

  void _showReadOnlyDetails(BuildContext context, TaskModel task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                Text("Görev (#${task.id}) İçeriği", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor)),
                const SizedBox(height: 15),

                ...task.items.map((item) => Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.inventory_2_outlined, color: primaryColor, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(item['productName'] ?? 'Bilinmiyor', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _infoBadge(Icons.grid_3x3, "ID: ${item['productId'] ?? '-'}"),
                            _infoBadge(Icons.shelves, "Raf: ${item['shelfCode'] ?? '-'}"),
                            _infoBadge(Icons.inventory, "İstenen: ${item['quantity'] ?? 1}"), // Burayı da miktara göre güncelledim
                          ],
                        ),
                      ],
                    ),
                  ),
                )).toList(),

                const SizedBox(height: 10),
                Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)), child: const Text("Tamamlandı ✅", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14)))),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoBadge(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
      ],
    );
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  String _workerName = "Yükleniyor...";
  int _completedTaskCount = 0;
  bool _isLoading = true;
  final Color primaryColor = const Color(0xFF1A237E);

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String name = prefs.getString('workerName') ?? "Saha Personeli";

    int count = 0;
    try {
      final completedTasks = await TaskService().getCompletedTasksForWorker();
      count = completedTasks.length;
    } catch (e) {
      print("İstatistik çekilemedi: $e");
    }

    if (mounted) {
      setState(() {
        _workerName = name;
        _completedTaskCount = count;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 55,
              backgroundColor: primaryColor.withOpacity(0.1),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: primaryColor,
                child: const Icon(Icons.person, size: 50, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            Text(_workerName, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: primaryColor)),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
              child: Text("Saha Görevlisi (Worker)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
            ),
            const SizedBox(height: 40),

            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.check_circle, size: 36, color: Colors.green),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Tamamlanan Görev", style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        _isLoading
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green))
                            : Text("$_completedTaskCount", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text("Sistemden Güvenli Çıkış", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.red.shade200, width: 1.5)
                  ),
                ),
                onPressed: () async {
                  await AuthService().logout();
                  if (!context.mounted) return;
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}