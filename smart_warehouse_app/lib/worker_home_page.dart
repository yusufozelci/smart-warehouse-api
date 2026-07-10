import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_warehouse_app/qr_scanner_page.dart';
import 'package:smart_warehouse_app/services/auth_service.dart';
import 'package:smart_warehouse_app/services/task_service.dart';
import 'package:smart_warehouse_app/models/task_model.dart';
import 'package:smart_warehouse_app/login_page.dart';

class WorkerHomePage extends StatefulWidget {
  const WorkerHomePage({super.key});

  @override
  State<WorkerHomePage> createState() => _WorkerHomePageState();
}

class _WorkerHomePageState extends State<WorkerHomePage> {
  int _currentIndex = 0;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(["Aktif Depo Görevleri", "Görev Geçmişi", "Personel Profili"][_currentIndex]),
        backgroundColor: Colors.blueAccent,
      ),
      body: [
        const _ActiveTasksTab(),
        const _CompletedTasksTab(),
        const _ProfileTab(),
      ][_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        selectedItemColor: Colors.blueAccent,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Aktif'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Geçmiş'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
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
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text("Hata: ${snapshot.error}"));
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Bekleyen görev yok."));

        final tasks = snapshot.data!;
        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text("Görev ID: ${task.id}"),
                subtitle: Text("Durum: ${task.status}"),
                trailing: const Icon(Icons.touch_app),
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
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Görev (#${task.id})", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  ...task.items.map((item) {
                    bool isPicked = item['isPicked'] == true;
                    return ListTile(
                      title: Text(item['productName'] ?? 'Ürün'),
                      subtitle: Text("SKU: ${item['sku']}"),
                      trailing: isPicked
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : ElevatedButton(
                        onPressed: () async {
                          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => QrScannerPage(expectedSku: item['sku'])));
                          if (result == true) {
                            bool success = await TaskService().pickItem(task.id, item['productId']);
                            if (success) {
                              setModalState(() { item['isPicked'] = true; });
                              _refreshTasks();
                            }
                          }
                        },
                        child: const Text("Tara"),
                      ),
                    );
                  }),
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TaskModel>>(
      future: TaskService().getCompletedTasksForWorker(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final tasks = snapshot.data!;
        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text("Görev ID: ${task.id}"),
              subtitle: Text("Toplam ${task.items.length} ürün toplandı."),
              onTap: () => _showReadOnlyDetails(context, task),
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

                Text("Görev (#${task.id}) İçeriği", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
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
                            const Icon(Icons.inventory_2_outlined, color: Colors.blueAccent, size: 20),
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
                            _infoBadge(Icons.inventory, "Stok: ${item['stockQuantity'] ?? 0}"),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blueAccent,
              child: Icon(Icons.person, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(_workerName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Rol: Saha Görevlisi (Worker)", style: TextStyle(fontSize: 16, color: Colors.black54)),
            const SizedBox(height: 30),
            Card(
              elevation: 2,
              color: Colors.green[50],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
                child: Column(
                  children: [
                    const Text("Tamamlanan Görev", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(height: 8),
                    _isLoading
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green))
                        : Text("$_completedTaskCount", style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text("Sistemden Güvenli Çıkış", style: TextStyle(fontSize: 16, color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  await AuthService().logout();
                  if (!context.mounted) return;
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginPage()));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildDetailRow(String title, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w500)),
        Flexible(child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
      ],
    ),
  );
}