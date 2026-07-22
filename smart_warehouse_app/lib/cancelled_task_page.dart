import 'package:flutter/material.dart';
import 'package:smart_warehouse_app/services/task_service.dart';
import 'package:smart_warehouse_app/models/task_model.dart';

class CancelledTasksPage extends StatefulWidget {
  const CancelledTasksPage({super.key});

  @override
  State<CancelledTasksPage> createState() => _CancelledTasksPageState();
}

class _CancelledTasksPageState extends State<CancelledTasksPage> {
  late Future<List<TaskModel>> _cancelledTasksFuture;
  final Color errorColor = Colors.red;
  final Color removedColor = Colors.orange.shade700;

  @override
  void initState() {
    super.initState();
    _cancelledTasksFuture = _fetchCancelledTasks();
  }

  Future<List<TaskModel>> _fetchCancelledTasks() async {
    final allTasks = await TaskService().getAllTasks();
    final cancelledTasks = allTasks.where((t) => t.status == 'CANCELLED' || t.status == 'CANCELED').toList();
    cancelledTasks.sort((a, b) => b.id.compareTo(a.id));
    return cancelledTasks;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("İptal Edilenler", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 1,
      ),
      body: FutureBuilder<List<TaskModel>>(
        future: _cancelledTasksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: errorColor));
          if (snapshot.hasError) return Center(child: Text("Hata: ${snapshot.error}", style: const TextStyle(color: Colors.red)));

          final tasks = snapshot.data ?? [];
          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel_outlined, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text("İptal edilen kayıt bulunmuyor.", style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              String timeStr = "Zaman Belirtilmedi";
              DateTime? targetDate = task.updatedAt ?? task.createdAt;

              if (targetDate != null) {
                DateTime localDate = targetDate.toLocal();
                timeStr = "${localDate.day.toString().padLeft(2, '0')}/${localDate.month.toString().padLeft(2, '0')}/${localDate.year} ${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}";
              }
              String reasonRaw = task.cancelReason ?? 'Belirtilmedi';
              bool isItemRemoved = reasonRaw.contains('[URUN_CIKARILDI');

              String originalTaskId = task.id.toString();
              String displayReason = reasonRaw;

              if (isItemRemoved) {
                final match = RegExp(r'\[URUN_CIKARILDI(?:-(\d+))?\]\s*(.*)').firstMatch(reasonRaw);
                if (match != null) {
                  if (match.group(1) != null) originalTaskId = match.group(1)!;
                  displayReason = match.group(2)!.trim();
                } else {
                  displayReason = reasonRaw.replaceAll(RegExp(r'\[URUN_CIKARILDI.*?\]\s*'), '').trim();
                }
              }

              String cardTitle = isItemRemoved ? "Çıkarılan Ürün (#$originalTaskId)" : "İptal Görev (#${task.id})";
              Color cardColor = isItemRemoved ? removedColor : errorColor;
              IconData cardIcon = isItemRemoved ? Icons.remove_shopping_cart : Icons.cancel;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: cardColor.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(cardIcon, color: cardColor, size: 28),
                  ),
                  title: Text(cardTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Atanan: ${task.assignedWorkerName}", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(timeStr, style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(isItemRemoved ? "1 Kalem Ürün" : "Toplam ${task.items.length} Kalem Ürün", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () => _showTaskDetails(context, task, isItemRemoved, cardColor, originalTaskId, displayReason, timeStr),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showTaskDetails(BuildContext context, TaskModel task, bool isItemRemoved, Color themeColor, String originalTaskId, String displayReason, String timeStr) {
    String titleText = isItemRemoved ? "Görevden Çıkarılan Ürün (#$originalTaskId)" : "İptal Edilen Görev (#${task.id})";
    String subtitleText = isItemRemoved ? "Bu ürün, $originalTaskId numaralı görev devam ederken listeden çıkarılmıştır." : "Bu görev sistem tarafından veya manuel olarak iptal edilmiştir.";

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
                Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                Text(titleText, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: themeColor)),
                const SizedBox(height: 10),
                Text(subtitleText, style: const TextStyle(color: Colors.grey)),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 10, bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: themeColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: themeColor, size: 20),
                          const SizedBox(width: 8),
                          Text("İşlem Detayları", style: TextStyle(fontWeight: FontWeight.bold, color: themeColor, fontSize: 16)),
                        ],
                      ),
                      const Divider(color: Colors.black12, height: 20),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: themeColor),
                          const SizedBox(width: 8),
                          Text(isItemRemoved ? "Çıkarılma Zamanı: " : "İptal Zamanı: ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                          Text(timeStr, style: TextStyle(color: Colors.grey.shade800)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person, size: 16, color: themeColor),
                          const SizedBox(width: 8),
                          Text(isItemRemoved ? "Çıkaran: " : "İptal Eden: ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                          Text(task.cancelledBy ?? 'Admin', style: TextStyle(color: Colors.grey.shade800)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.report_problem, size: 16, color: themeColor),
                          const SizedBox(width: 8),
                          const Text("Nedeni: ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                          Expanded(child: Text(displayReason, style: TextStyle(color: Colors.grey.shade800))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
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
                            Icon(isItemRemoved ? Icons.remove_shopping_cart : Icons.inventory_2_outlined, color: themeColor, size: 20),
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