import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';


import 'statistics_components.dart';

class StockChart extends StatelessWidget {
  const StockChart({super.key, required this.stats});

  final List<Map<String, dynamic>> stats;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Stok Hareketleri',
        icon: Icons.show_chart_rounded,
        action: const _ChartLegend(
          items: [
            ('Stok Girişi', Color(0xFF16A36A)),
            ('Stok Çıkışı', Color(0xFFE53935)),
          ],
        ),
        child: SizedBox(
          height: 270,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child: LineChart(
              _chartData(),
              key: ValueKey(stats.map((e) => '${e['entries']}-${e['exits']}').join()),
            ),
          ),
        ),
      );

  LineChartData _chartData() => LineChartData(
        minX: 0,
        maxX: max(0, stats.length - 1).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: const Color(0xFFE8ECF2), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) => touched
                .map(
                  (spot) => LineTooltipItem(
                    '${spot.barIndex == 0 ? 'Stok Girişi' : 'Stok Çıkışı'}\n${spot.y.toStringAsFixed(0)} adet',
                    TextStyle(
                      color: spot.barIndex == 0 ? const Color(0xFF16A36A) : const Color(0xFFE53935),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (value, _) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: Color(0xFF7B8495)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                final index = value.toInt();
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    index >= 0 && index < stats.length ? '${stats[index]['day']}' : '',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF687386)),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          _line(const Color(0xFF16A36A), (e) => e['entries']),
          _line(const Color(0xFFE53935), (e) => e['exits']),
        ],
      );

  LineChartBarData _line(Color color, dynamic Function(Map<String, dynamic>) value) => LineChartBarData(
        spots: stats.asMap().entries.map((e) => FlSpot(e.key.toDouble(), ((value(e.value) ?? 0) as num).toDouble())).toList(),
        isCurved: true,
        curveSmoothness: .32,
        barWidth: 4,
        isStrokeCapRound: true,
        gradient: LinearGradient(colors: [color.withValues(alpha: .75), color]),
        dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 3.5, color: Colors.white, strokeWidth: 2.5, strokeColor: color)),
        belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: .22), color.withValues(alpha: 0)])),
      );
}

class TaskChart extends StatelessWidget {
  const TaskChart({super.key, required this.stats});

  final List<Map<String, dynamic>> stats;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Görev Aktivitesi',
        icon: Icons.bar_chart_rounded,
        action: const _ChartLegend(items: [('Oluşturulan', Color(0xFF4285F4)), ('Tamamlanan', Color(0xFF16A36A)), ('İptal', Color(0xFFE53935))]),
        child: SizedBox(height: 245, child: AnimatedSwitcher(duration: const Duration(milliseconds: 450), child: BarChart(_data(), key: ValueKey(stats.map((e) => '${e['created']}-${e['completed']}-${e['cancelled']}').join())))),
      );

  BarChartData _data() {
    final maxValue = stats.fold<int>(0, (maxValue, item) => max(maxValue, max(item['created'] as int, max(item['completed'] as int, item['cancelled'] as int)))) + 3;
    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxValue.toDouble(),
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: const Color(0xFFE8ECF2))),
      borderData: FlBorderData(show: false),
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            const names = ['Oluşturulan', 'Tamamlanan', 'İptal Edilen'];
            return BarTooltipItem('${names[rodIndex]}\n${rod.toY.toInt()} görev', const TextStyle(color: Colors.white, fontWeight: FontWeight.w700));
          },
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, _) {
              final index = value.toInt();
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(index >= 0 && index < stats.length ? '${stats[index]['day']}' : '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF687386))),
              );
            },
          ),
        ),
      ),
      barGroups: stats.asMap().entries.map((entry) => BarChartGroupData(x: entry.key, barsSpace: 5, barRods: [_rod(entry.value['created'], const Color(0xFF4285F4)), _rod(entry.value['completed'], const Color(0xFF16A36A)), _rod(entry.value['cancelled'], const Color(0xFFE53935))])).toList(),
    );
  }

  BarChartRodData _rod(dynamic value, Color color) => BarChartRodData(toY: ((value ?? 0) as num).toDouble(), width: 10, gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [color.withValues(alpha: .72), color]), borderRadius: const BorderRadius.vertical(top: Radius.circular(6)));
}

class TaskPieChart extends StatelessWidget {
  const TaskPieChart({super.key, required this.pending, required this.inProgress, required this.completed, required this.cancelled});

  final int pending;
  final int inProgress;
  final int completed;
  final int cancelled;

  @override
  Widget build(BuildContext context) {
    final total = pending + inProgress + completed + cancelled;
    final values = [pending, inProgress, completed, cancelled];
    const colors = [Color(0xFFFFA000), kAnalyticsPurple, Color(0xFF16A36A), Color(0xFFE53935)];
    const labels = ['Bekleyen', 'İşlemde', 'Tamamlandı', 'İptal Edildi'];
    return SectionCard(
      title: 'Görev Durum Dağılımı',
      icon: Icons.pie_chart_rounded,
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 56,
                    pieTouchData: PieTouchData(enabled: true),
                    sections: List.generate(
                      4,
                      (index) => PieChartSectionData(
                        value: values[index].toDouble(),
                        color: colors[index],
                        radius: 26,
                        showTitle: false,
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$total', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
                    const Text('TOPLAM GÖREV', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF778196))),
                  ],
                ),
              ],
            ),
          ),
          Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 8, children: List.generate(4, (i) => _LegendDot('${labels[i]} (${values[i]})', colors[i]))),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.items});
  final List<(String, Color)> items;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 10, runSpacing: 4, children: items.map((item) => _LegendDot(item.$1, item.$2)).toList());
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 4), Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF687386)))]);
}
