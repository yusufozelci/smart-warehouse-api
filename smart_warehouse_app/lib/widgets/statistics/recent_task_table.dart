import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/task_model.dart';
import 'statistics_components.dart';

class RecentTaskTable extends StatelessWidget {
  const RecentTaskTable({super.key, required this.tasks});
  final List<TaskModel> tasks;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Son İşlemler',
      icon: Icons.history_rounded,
      action: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: kAnalyticsPurple.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
        child: Text('${tasks.length} Görev', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kAnalyticsPurple)),
      ),
      child: tasks.isEmpty
          ? const SizedBox(
        height: 120,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, color: Color(0xFFC0C6D4), size: 32),
              SizedBox(height: 8),
              Text('Henüz gösterilecek işlem bulunmuyor.', style: TextStyle(color: Color(0xFF778196), fontSize: 13)),
            ],
          ),
        ),
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Özel Tablo Başlığı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFFF7F9FC), borderRadius: BorderRadius.circular(10)),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('GÖREV', style: _headerStyle)),
                Expanded(flex: 3, child: Text('PERSONEL', style: _headerStyle)),
                Expanded(flex: 2, child: Text('DURUM', style: _headerStyle)),
                Expanded(flex: 3, child: Text('OLUŞTURMA', style: _headerStyle)),
                Expanded(flex: 3, child: Text('TAMAMLANMA', style: _headerStyle)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Tablo Satırları
          ...tasks.take(8).map((task) => _TaskRowItem(task: task)),
        ],
      ),
    );
  }

  static const _headerStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF687386), letterSpacing: 0.5);
}

class _TaskRowItem extends StatefulWidget {
  const _TaskRowItem({required this.task});
  final TaskModel task;

  @override
  State<_TaskRowItem> createState() => _TaskRowItemState();
}

class _TaskRowItemState extends State<_TaskRowItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFFF9FAFB) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _isHovered ? const Color(0xFFE2E8F0) : Colors.transparent),
        ),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text('#${widget.task.id}', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1D2230), fontSize: 13))),
            Expanded(flex: 3, child: Text(widget.task.assignedWorkerName, style: const TextStyle(color: Color(0xFF4B5568), fontWeight: FontWeight.w600, fontSize: 13))),
            Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _StatusBadge(status: widget.task.status))),
            Expanded(flex: 3, child: Text(_formatDate(widget.task.createdAt), style: const TextStyle(color: Color(0xFF687386), fontSize: 13))),
            Expanded(flex: 3, child: Text(widget.task.status == 'COMPLETED' ? _formatDate(widget.task.updatedAt) : '—', style: const TextStyle(color: Color(0xFF687386), fontSize: 13))),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) => date == null ? '—' : DateFormat('dd MMM, HH:mm', 'tr').format(date.toLocal());
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final data = switch (status) {
      'COMPLETED' => ('Tamamlandı', const Color(0xFF0F9D58)),
      'CANCELLED' || 'DELETED' => ('İptal Edildi', const Color(0xFFD93025)),
      'PENDING' => ('Bekleyen', const Color(0xFFF57C00)),
      _ => ('İşlemde', kAnalyticsPurple),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: data.$2.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(data.$1, style: TextStyle(fontSize: 11, color: data.$2, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
    );
  }
}