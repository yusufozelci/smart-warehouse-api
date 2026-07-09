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
    final List<Widget> _pages = [
      const _ActiveTasksTab(),
      const _CompletedTasksTab(),
      const _ProfileTab(),
    ];

    final List<String> _titles = [
      "Aktif Depo Görevleri",
      "Görev Geçmişi",
      "Personel Profili"
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        backgroundColor: Colors.blueAccent,
        elevation: 2,
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Aktif Görevler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Geçmiş',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text("Hata: ${snapshot.error}"));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("Şu an bekleyen görev bulunmuyor."));
        }

        final tasks = snapshot.data!;
        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: const Icon(Icons.inventory_2, color: Colors.blue),
                ),
                title: Text("Görev ID: ${task.id}", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Raf: ${task.items.isNotEmpty ? task.items[0]['shelfCode'] : 'Yok'} | Durum: ${task.status}"),
                trailing: const Icon(Icons.touch_app, size: 20, color: Colors.grey),
                onTap: () => _showTaskDetails(context, task, isHistory: false),
              ),
            );
          },
        );
      },
    );
  }

  void _showTaskDetails(BuildContext context, TaskModel task, {required bool isHistory}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext sheetContext) {
        final item = task.items.isNotEmpty ? task.items[0] : null;

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).padding.bottom + 20, top: 20, left: 20, right: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 20),
                Text("Görev Detayı (#${task.id})", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Divider(thickness: 1, height: 30),

                if (item != null) ...[
                  _buildDetailRow("Ürün ID:", item['productId']?.toString() ?? 'Bilinmiyor'),
                  _buildDetailRow("Ürün Adı:", item['productName'] ?? 'Bilinmiyor'),
                  _buildDetailRow("Ürün Kodu (SKU):", item['sku'] ?? 'Bilinmiyor'),
                  _buildDetailRow("Mevcut Stok:", "${item['stockQuantity'] ?? 0} Adet"),
                  const Divider(thickness: 0.5, height: 20),
                  _buildDetailRow("Raf Kodu:", item['shelfCode'] ?? 'Bilinmiyor'),
                  const Divider(thickness: 0.5, height: 20),
                  _buildDetailRow("Toplanacak Miktar:", "${item['quantity']} Adet"),
                  _buildDetailRow("Ürün Durumu:", item['isPicked'] == true ? "Toplandı" : "Bekliyor"),
                  _buildDetailRow("Genel Görev Durumu:", task.status),
                ],

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                    label: const Text("QR Kod ile Ürünü Doğrula", style: TextStyle(fontSize: 16, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      final String expectedSku = item?['sku'] ?? '';
                      if(expectedSku.isEmpty || expectedSku == 'Bilinmiyor') return;

                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      Navigator.pop(sheetContext);

                      final bool? isVerified = await navigator.push(
                        MaterialPageRoute(builder: (context) => QrScannerPage(expectedSku: expectedSku)),
                      );

                      if (isVerified == true) {
                        messenger.showSnackBar(const SnackBar(content: Text("✅ Ürün Doğrulandı! Görev Tamamlanıyor..."), backgroundColor: Colors.orange));
                        bool isSuccess = await TaskService().completeTask(task.id);

                        if (isSuccess) {
                          messenger.showSnackBar(const SnackBar(content: Text("🎉 Görev Başarıyla Tamamlandı!"), backgroundColor: Colors.green));
                          _refreshTasks();
                        } else {
                          messenger.showSnackBar(const SnackBar(content: Text("Sunucu Hatası: İşlem reddedildi!"), backgroundColor: Colors.red));
                        }
                      } else if (isVerified == false) {
                        messenger.showSnackBar(const SnackBar(content: Text("❌ Yanlış Ürün! Tekrar kontrol edin."), backgroundColor: Colors.red));
                      }
                    },
                  ),
                )
              ],
            ),
          ),
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text("Hata: ${snapshot.error}"));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("Henüz tamamlanmış bir görev yok."));
        }

        final tasks = snapshot.data!;
        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 1,
              color: Colors.green[50],
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green[100],
                  child: const Icon(Icons.check_circle, color: Colors.green),
                ),
                title: Text("Görev ID: ${task.id}", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Raf: ${task.items.isNotEmpty ? task.items[0]['shelfCode'] : 'Yok'} | Durum: ${task.status}"),
                trailing: const Icon(Icons.visibility, size: 20, color: Colors.green),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext sheetContext) {
        final item = task.items.isNotEmpty ? task.items[0] : null;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).padding.bottom + 20, top: 20, left: 20, right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Text("Tamamlanan Görev Detayı (#${task.id})", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
              const Divider(thickness: 1, height: 30),
              if (item != null) ...[
                _buildDetailRow("Ürün Adı:", item['productName'] ?? 'Bilinmiyor'),
                _buildDetailRow("Ürün Kodu (SKU):", item['sku'] ?? 'Bilinmiyor'),
                _buildDetailRow("Raf Kodu:", item['shelfCode'] ?? 'Bilinmiyor'),
                _buildDetailRow("Toplanan Miktar:", "${item['quantity']} Adet"),
                _buildDetailRow("Durum:", "Tamamlandı ✅"),
              ],
              const SizedBox(height: 20),
            ],
          ),
        );
      },
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

            Text(
                _workerName,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 8),
            const Text(
                "Rol: Saha Görevlisi (Worker)",
                style: TextStyle(fontSize: 16, color: Colors.black54)
            ),

            const SizedBox(height: 30),

            Card(
              elevation: 2,
              color: Colors.green[50],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
                child: Column(
                  children: [
                    const Text(
                        "Tamamlanan Görev",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)
                    ),
                    const SizedBox(height: 8),
                    _isLoading
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green))
                        : Text(
                        "$_completedTaskCount",
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.green)
                    ),
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