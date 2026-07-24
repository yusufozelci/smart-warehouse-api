import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/worker_performance_model.dart';

class PerformanceDashboardWidget extends StatelessWidget {
  final WorkerPerformanceModel data;

  const PerformanceDashboardWidget({super.key, required this.data});
  String _formatDuration(int totalMinutes) {
    if (totalMinutes == 0) return "0 dk";
    if (totalMinutes < 60) return "$totalMinutes dk";

    int hours = totalMinutes ~/ 60;
    int minutes = totalMinutes % 60;

    if (minutes == 0) return "$hours sa";
    return "$hours sa $minutes dk";
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: double.infinity,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildStatCard("Başarı Oranı", "%${data.successRate}", Icons.pie_chart, Colors.purple),
              _buildStatCard("Ortalama Süre", _formatDuration(data.averageTaskDurationMinutes), Icons.timer, Colors.blue),
              _buildStatCard("Toplanan", "${data.totalCollectedItems}", Icons.inventory, Colors.orange),
              _buildStatCard("Tamamlanan", "${data.completedTasks}/${data.totalTasksAssigned}", Icons.check_circle, Colors.green),
              _buildStatCard("İptal Edilen", "${data.cancelledTasks}", Icons.cancel, Colors.red),
            ],
          ),
        ),
        const SizedBox(height: 30),
        Row(
          children: [
            Expanded(
              child: _buildChart("Son 7 Gün", data.weeklyGraphData, isMonthly: false),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildChart("Son 30 Gün", data.monthlyGraphData, isMonthly: true),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChart(String title, List<DailyPerformanceModel> chartData, {required bool isMonthly}) {
    double maxY = _getMaxY(chartData) + 2;

    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 12),
        Container(
          height: 240,
          padding: const EdgeInsets.only(top: 24, bottom: 12, left: 8, right: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withOpacity(0.05),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${rod.toY.toInt()} Görev\n',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      children: [
                        TextSpan(
                          text: chartData[group.x].date,
                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.normal),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      int index = value.toInt();
                      if (index >= chartData.length) return const Text("");

                      if (isMonthly && index % 5 != 0 && index != chartData.length - 1) return const Text("");

                      String date = chartData[index].date;
                      String day = date.split('-').last;
                      return Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: Text(day, style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) {
                      if (value % 1 != 0 || value == maxY) return const SizedBox.shrink();
                      return Text(value.toInt().toString(), style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.w500));
                    },
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 2,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1.5,
                    dashArray: [6, 6],
                  );
                },
              ),
              barGroups: List.generate(
                chartData.length,
                    (index) => BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: chartData[index].completedTaskCount.toDouble(),
                      gradient: LinearGradient(
                        colors: isMonthly
                            ? [Colors.teal.shade300, Colors.teal.shade700]
                            : [Colors.blue.shade300, const Color(0xFF1A237E)],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      width: isMonthly ? 7 : 20,
                      borderRadius: BorderRadius.circular(6),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY,
                        color: Colors.grey.shade100,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _getMaxY(List<DailyPerformanceModel> chartData) {
    if (chartData.isEmpty) return 10;
    double max = 0;
    for (var item in chartData) {
      if (item.completedTaskCount > max) max = item.completedTaskCount.toDouble();
    }
    return max == 0 ? 10 : max;
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}