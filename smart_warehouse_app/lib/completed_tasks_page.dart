import 'package:flutter/material.dart';
import 'package:smart_warehouse_app/services/task_service.dart';
import 'package:smart_warehouse_app/models/task_model.dart';

class CompletedTasksPage extends StatefulWidget {
  const CompletedTasksPage({super.key});

  @override
  State<CompletedTasksPage> createState() => _CompletedTasksPageState();
}

class _CompletedTasksPageState extends State<CompletedTasksPage> {
  late Future<List<TaskModel>> _completedTasksFuture;
  final Color primaryColor = const Color(0xFF6200EA);

  @override
  void initState() {
    super.initState();
    _completedTasksFuture = _fetchCompletedTasks();
  }

  Future<List<TaskModel>> _fetchCompletedTasks() async {
    final allTasks = await TaskService().getAllTasks();
    final completedTasks = allTasks.where((t) => t.status == 'COMPLETED').toList();
    completedTasks.sort((a, b) => b.id.compareTo(a.id));
    return completedTasks;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Tamamlanan Görevler", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 1,
      ),
      body: FutureBuilder<List<TaskModel>>(
        future: _completedTasksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
          }
          if (snapshot.hasError) {
            return Center(child: Text("Hata: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          }

          final tasks = snapshot.data ?? [];

          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text("Sistemde henüz tamamlanmış görev yok.", style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle, color: Colors.green, size: 28),
                  ),
                  title: Text("Görev ID: #${task.id}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Toplayan: ${task.assignedWorkerName}", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text("Toplam ${task.items.length} Kalem Ürün", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () => _showTaskDetails(context, task),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showTaskDetails(BuildContext context, TaskModel task) {
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
                Center(
                  child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                ),
                Text("Görev (#${task.id}) Raporu", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor)),
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
                            _infoBadge(Icons.grid_3x3, "SKU: ${item['sku'] ?? '-'}"),
                            _infoBadge(Icons.shelves, "Raf: ${item['shelfCode'] ?? '-'}"),
                            _infoBadge(Icons.inventory, "Miktar: ${item['quantity'] ?? 1}"),
                          ],
                        ),
                      ],
                    ),
                  ),
                )).toList(),

                const SizedBox(height: 10),
                Center(
                    child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
                        child: const Text("Tüm Ürünler Toplandı ✅", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14))
                    )
                ),
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