import 'package:flutter/material.dart';
import 'statistics_components.dart';

enum ReportPeriod { daily, weekly, monthly }
enum ReportFormat { pdf, excel }

class ReportsPanel extends StatelessWidget {
  const ReportsPanel({super.key, required this.onExport});
  final Future<void> Function(ReportPeriod period, ReportFormat format) onExport;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Dışa Aktarım & Raporlama',
      icon: Icons.summarize_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Yönetim onaylı operasyon özetlerini PDF veya Excel formatında cihazınıza indirin.', style: TextStyle(fontSize: 13, color: Color(0xFF687386), height: 1.5)),
          const SizedBox(height: 20),
          _ReportActionCard(
            title: 'Günlük Operasyon Raporu',
            subtitle: 'Bugünün tüm stok ve görev hareketleri',
            icon: Icons.today_outlined,
            onPdf: () => onExport(ReportPeriod.daily, ReportFormat.pdf),
            onExcel: () => onExport(ReportPeriod.daily, ReportFormat.excel),
          ),
          _ReportActionCard(
            title: 'Haftalık Sistem Raporu',
            subtitle: 'Son 7 günün detaylı personel ve kapasite analizi',
            icon: Icons.date_range_outlined,
            onPdf: () => onExport(ReportPeriod.weekly, ReportFormat.pdf),
            onExcel: () => onExport(ReportPeriod.weekly, ReportFormat.excel),
          ),
          _ReportActionCard(
            title: 'Aylık Yönetim Raporu',
            subtitle: 'Stratejik planlama için geniş kapsamlı depo verileri',
            icon: Icons.calendar_month_outlined,
            onPdf: () => onExport(ReportPeriod.monthly, ReportFormat.pdf),
            onExcel: () => onExport(ReportPeriod.monthly, ReportFormat.excel),
          ),
        ],
      ),
    );
  }
}

class _ReportActionCard extends StatefulWidget {
  const _ReportActionCard({required this.title, required this.subtitle, required this.icon, required this.onPdf, required this.onExcel});
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onPdf;
  final VoidCallback onExcel;

  @override
  State<_ReportActionCard> createState() => _ReportActionCardState();
}

class _ReportActionCardState extends State<_ReportActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _isHovered ? kAnalyticsPurple.withOpacity(0.4) : const Color(0xFFE8ECF2)),
          boxShadow: _isHovered ? [BoxShadow(color: kAnalyticsPurple.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kAnalyticsPurple.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
              child: Icon(widget.icon, color: kAnalyticsPurple, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1D2230))),
                  const SizedBox(height: 4),
                  Text(widget.subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF778196))),
                ],
              ),
            ),
            _ExportButton(label: 'PDF', icon: Icons.picture_as_pdf_rounded, color: const Color(0xFFD93025), onTap: widget.onPdf),
            const SizedBox(width: 8),
            _ExportButton(label: 'Excel', icon: Icons.table_view_rounded, color: const Color(0xFF0F9D58), onTap: widget.onExcel),
          ],
        ),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.label, required this.icon, required this.color, required this.onTap});
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$label İndir',
      child: Material(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: color.withOpacity(0.2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}