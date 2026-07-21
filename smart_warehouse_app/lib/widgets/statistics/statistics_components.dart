import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

const kAnalyticsPurple = Color(0xFF6200EA);

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

  LineChartData _chartData() {
    double maxY = 10.0;
    for (var stat in stats) {
      if (((stat['entries'] ?? 0) as num).toDouble() > maxY) maxY = ((stat['entries'] ?? 0) as num).toDouble();
      if (((stat['exits'] ?? 0) as num).toDouble() > maxY) maxY = ((stat['exits'] ?? 0) as num).toDouble();
    }
    maxY = maxY * 1.2;

    return LineChartData(
      minX: 0,
      maxX: max(0, stats.length - 1).toDouble(),
      minY: 0,
      maxY: maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY / 5,
        getDrawingHorizontalLine: (_) => FlLine(color: const Color(0xFFE8ECF2), strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touched) => touched.map(
                (spot) => LineTooltipItem(
              '${spot.barIndex == 0 ? 'Stok Girişi' : 'Stok Çıkışı'}\n${spot.y.toStringAsFixed(0)} adet',
              TextStyle(color: spot.barIndex == 0 ? const Color(0xFF16A36A) : const Color(0xFFE53935), fontWeight: FontWeight.w700),
            ),
          ).toList(),
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 34,
            interval: maxY / 5,
            getTitlesWidget: (value, _) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: Color(0xFF7B8495))),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
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
  }

  LineChartBarData _line(Color color, dynamic Function(Map<String, dynamic>) value) => LineChartBarData(
    spots: stats.asMap().entries.map((e) => FlSpot(e.key.toDouble(), ((value(e.value) ?? 0) as num).toDouble())).toList(),
    isCurved: true,
    curveSmoothness: .32,
    barWidth: 4,
    isStrokeCapRound: true,
    gradient: LinearGradient(colors: [color.withOpacity(.75), color]),
    dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 3.5, color: Colors.white, strokeWidth: 2.5, strokeColor: color)),
    belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withOpacity(.22), color.withOpacity(0)])),
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
      gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxValue / 4) < 1 ? 1 : (maxValue / 4),
          getDrawingHorizontalLine: (_) => FlLine(color: const Color(0xFFE8ECF2))
      ),
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
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: (maxValue / 4) < 1 ? 1 : (maxValue / 4),
                getTitlesWidget: (value, _) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: Color(0xFF7B8495)))
            )
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
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

  BarChartRodData _rod(dynamic value, Color color) => BarChartRodData(toY: ((value ?? 0) as num).toDouble(), width: 10, gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [color.withOpacity(.72), color]), borderRadius: const BorderRadius.vertical(top: Radius.circular(6)));
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
          const SizedBox(height: 12),
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

class KpiCard extends StatefulWidget {
  const KpiCard({super.key, required this.title, required this.value, required this.icon, required this.color, required this.trendLabel, required this.isPositive, required this.progress});
  final String title; final String value; final IconData icon; final Color color; final String trendLabel; final bool isPositive; final double progress;

  @override
  State<KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<KpiCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final trendColor = widget.isPositive ? const Color(0xFF0F9D58) : const Color(0xFFD93025);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: widget.color.withOpacity(.14)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(_hovered ? .14 : .06), blurRadius: _hovered ? 24 : 12, offset: Offset(0, _hovered ? 12 : 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF687386)))),
                Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: widget.color.withOpacity(.12), borderRadius: BorderRadius.circular(12)), child: Icon(widget.icon, color: widget.color, size: 25)),
              ],
            ),
            const Spacer(),
            Text(widget.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 25, height: 1, fontWeight: FontWeight.w800, color: Color(0xFF171B26))),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(widget.isPositive ? Icons.north_east_rounded : Icons.south_east_rounded, color: trendColor, size: 15),
                const SizedBox(width: 3),
                Expanded(child: Text(widget.trendLabel, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: trendColor))),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: widget.progress.clamp(0, 1).toDouble(), minHeight: 5, backgroundColor: widget.color.withOpacity(.1), valueColor: AlwaysStoppedAnimation(widget.color))),
          ],
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.icon, required this.child, this.action});
  final String title; final IconData icon; final Widget child; final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 16, offset: const Offset(0, 6))]),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kAnalyticsPurple.withOpacity(.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: kAnalyticsPurple, size: 20)),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF202532)))),
            if (action != null) action!,
          ]),
          const SizedBox(height: 22),
          child,
        ],
      ),
    ),
  );
}

class OccupancyCard extends StatelessWidget {
  const OccupancyCard({super.key, required this.occupancy, required this.shelfCount, required this.usedWeight});
  final Map<String, double> occupancy; final int shelfCount; final double usedWeight;

  @override
  Widget build(BuildContext context) {
    final percentage = occupancy['genel'] ?? 0;
    final capacity = shelfCount * 320.0;
    return SectionCard(
      title: 'Depo Doluluk',
      icon: Icons.donut_large_rounded,
      child: Column(children: [
        Row(children: [
          SizedBox(width: 142, height: 142, child: Stack(fit: StackFit.expand, children: [
            CircularProgressIndicator(value: percentage / 100, strokeWidth: 13, strokeCap: StrokeCap.round, backgroundColor: kAnalyticsPurple.withOpacity(.1), valueColor: const AlwaysStoppedAnimation(kAnalyticsPurple)),
            Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('${percentage.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)), const Text('DOLULUK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF778196)))])),
          ])),
          const SizedBox(width: 22),
          Expanded(child: Column(children: [
            _capacityLine('Toplam Kapasite', '${capacity.toStringAsFixed(0)} kg', Icons.inventory_2_outlined),
            _capacityLine('Kullanılan', '${usedWeight.toStringAsFixed(0)} kg', Icons.check_circle_outline, color: const Color(0xFF0F9D58)),
            _capacityLine('Boş', '${(capacity - usedWeight).clamp(0, capacity).toStringAsFixed(0)} kg', Icons.space_bar_outlined, color: const Color(0xFF687386)),
          ])),
        ]),
        const SizedBox(height: 22),
        _floorProgress('Kat 1', occupancy['kat1'] ?? 0, const Color(0xFF4285F4)),
        _floorProgress('Kat 2', occupancy['kat2'] ?? 0, const Color(0xFFFB8C00)),
        _floorProgress('Kat 3', occupancy['kat3'] ?? 0, const Color(0xFF00A896)),
      ]),
    );
  }

  Widget _capacityLine(String label, String value, IconData icon, {Color color = kAnalyticsPurple}) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [Icon(icon, size: 17, color: color), const SizedBox(width: 7), Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF687386)))), Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))]));

  Widget _floorProgress(String title, double value, Color color) => Padding(padding: const EdgeInsets.only(top: 9), child: Column(children: [Row(children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), const Spacer(), Text('${value.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))]), const SizedBox(height: 6), ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: value / 100, minHeight: 7, backgroundColor: color.withOpacity(.12), valueColor: AlwaysStoppedAnimation(color))) ]));
}

class QuickInfoCard extends StatelessWidget {
  const QuickInfoCard({super.key, required this.items});
  final List<QuickInfo> items;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Hızlı Bilgiler',
    icon: Icons.auto_awesome_outlined,
    child: Column(children: items.map((item) => Padding(padding: const EdgeInsets.only(bottom: 15), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: item.color.withOpacity(.12), borderRadius: BorderRadius.circular(9)), child: Icon(item.icon, size: 17, color: item.color)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.label, style: const TextStyle(fontSize: 11, color: Color(0xFF778196))), const SizedBox(height: 2), Text(item.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))]))]))).toList()),
  );
}

class QuickInfo { const QuickInfo(this.label, this.value, this.icon, this.color); final String label; final String value; final IconData icon; final Color color; }

class HeatMapCard extends StatelessWidget {
  const HeatMapCard({super.key, required this.shelves, required this.shelfWeights});
  final List<dynamic> shelves; final Map<String, double> shelfWeights;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Raf Isı Haritası',
    icon: Icons.grid_view_rounded,
    action: const _HeatMapLegend(),
    child: Wrap(
      spacing: 9, runSpacing: 9,
      children: shelves.map((shelf) {
        final code = '${shelf['shelfCode'] ?? shelf['id'] ?? 'Raf'}';
        final weight = shelfWeights[code] ?? 0;
        final ratio = (weight / 320 * 100).clamp(0, 100);
        final color = ratio < 40 ? const Color(0xFF20A464) : ratio < 80 ? const Color(0xFFFF9800) : const Color(0xFFE53935);
        return Tooltip(message: 'Kod: $code\nDoluluk: ${ratio.toStringAsFixed(1)}%\nToplam ağırlık: ${weight.toStringAsFixed(1)} kg', child: Container(width: 50, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: color.withOpacity(.16), border: Border.all(color: color.withOpacity(.62)), borderRadius: BorderRadius.circular(10)), child: Text(code, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color))));
      }).toList(),
    ),
  );
}

class _HeatMapLegend extends StatelessWidget {
  const _HeatMapLegend();
  @override
  Widget build(BuildContext context) => const Wrap(spacing: 7, children: [_LegendDot('0–40%', Color(0xFF20A464)), _LegendDot('40–80%', Color(0xFFFF9800)), _LegendDot('80%+', Color(0xFFE53935))]);
}