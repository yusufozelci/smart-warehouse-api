import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/task_model.dart';
import 'services/task_service.dart';
import 'services/websocket_service.dart';
import 'widgets/statistics/reports_panel.dart';
import 'widgets/statistics/statistics_components.dart';
import 'services/report_export_service.dart';

class OperationStatisticsPage extends StatefulWidget {
  const OperationStatisticsPage({super.key});

  @override
  State<OperationStatisticsPage> createState() => _OperationStatisticsPageState();
}

class _OperationStatisticsPageState extends State<OperationStatisticsPage> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isRealtimeRefreshPending = false;
  List<dynamic> _stockMovements = [];
  List<dynamic> _allProducts = [];
  List<dynamic> _shelves = [];
  List<TaskModel> _tasks = [];
  DateTime _selectedDate = DateTime.now();
  DateTime? _lastUpdated;
  late final AnimationController _entranceController;

  String get baseUrl => kIsWeb ? 'http://localhost:8080' : (Platform.isAndroid ? 'http://10.0.2.2:8080' : 'http://localhost:8080');

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 520))..forward();
    final wsUrl = baseUrl.replaceFirst('http://', 'ws://') + '/ws-warehouse';
    WebSocketService.instance.connect(wsUrl);
    WebSocketService.instance.subscribe(_onLiveEvent);
    _fetchData();
  }

  void _onLiveEvent(Map<String, dynamic> _) {
    if (!mounted || _isRealtimeRefreshPending) return;
    _isRealtimeRefreshPending = true;
    _fetchData().whenComplete(() => _isRealtimeRefreshPending = false);
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final headers = {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};

      final shelfRes = await http.get(Uri.parse('$baseUrl/api/v1/shelves'), headers: headers);
      final prodRes = await http.get(Uri.parse('$baseUrl/api/v1/products'), headers: headers);
      final movementRes = await http.get(Uri.parse('$baseUrl/api/v1/stock-movements'), headers: headers);
      final tasks = await TaskService().getAllTasks();

      if (!mounted) return;
      setState(() {
        _shelves = shelfRes.statusCode == 200 ? jsonDecode(utf8.decode(shelfRes.bodyBytes)) : [];
        _allProducts = prodRes.statusCode == 200 ? jsonDecode(utf8.decode(prodRes.bodyBytes)) : [];
        _stockMovements = movementRes.statusCode == 200 ? jsonDecode(utf8.decode(movementRes.bodyBytes)) : [];
        _tasks = tasks;
        _lastUpdated = DateTime.now();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, double> _calculateOccupancyRates() {
    if (_shelves.isEmpty) return {'genel': 0.0, 'kat1': 0.0, 'kat2': 0.0, 'kat3': 0.0};
    double maxCapacity = 320.0;
    double tCap = _shelves.length * maxCapacity;
    double f1Cap = _shelves.where((s) => s['floor'] == 1).length * maxCapacity;
    double f2Cap = _shelves.where((s) => s['floor'] == 2).length * maxCapacity;
    double f3Cap = _shelves.where((s) => s['floor'] == 3).length * maxCapacity;

    double tWeight = 0.0, f1Weight = 0.0, f2Weight = 0.0, f3Weight = 0.0;

    for (var p in _allProducts) {
      double weight = (p['stockQuantity'] ?? 0).toDouble() * (p['weight'] ?? 0.0).toDouble();
      if (weight > 0) {
        tWeight += weight;
        var s = _shelves.firstWhere((sh) => sh['shelfCode'] == p['shelfCode'], orElse: () => null);
        if (s != null) {
          int f = s['floor'] ?? 1;
          if (f == 1) f1Weight += weight;
          else if (f == 2) f2Weight += weight;
          else if (f == 3) f3Weight += weight;
        }
      }
    }
    return {
      'genel': tCap > 0 ? ((tWeight / tCap) * 100).clamp(0.0, 100.0) : 0.0,
      'kat1': f1Cap > 0 ? ((f1Weight / f1Cap) * 100).clamp(0.0, 100.0) : 0.0,
      'kat2': f2Cap > 0 ? ((f2Weight / f2Cap) * 100).clamp(0.0, 100.0) : 0.0,
      'kat3': f3Cap > 0 ? ((f3Weight / f3Cap) * 100).clamp(0.0, 100.0) : 0.0,
    };
  }

  List<Map<String, dynamic>> _getWeeklyTaskStats() {
    List<Map<String, dynamic>> stats = [];
    DateTime today = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      DateTime date = today.subtract(Duration(days: i));
      String dayLabel = DateFormat('E', 'tr').format(date);
      int created = _tasks.where((t) => t.createdAt?.toLocal().day == date.day).length;
      int completed = _tasks.where((t) => t.status == 'COMPLETED' && t.updatedAt?.toLocal().day == date.day).length;
      int cancelled = _tasks.where((t) => t.status == 'CANCELLED' && t.updatedAt?.toLocal().day == date.day).length;
      stats.add({'day': dayLabel, 'created': created, 'completed': completed, 'cancelled': cancelled});
    }
    return stats;
  }

  int _countByStatus(Iterable<String> statuses) => _tasks.where((task) => statuses.contains(task.status)).length;
  int _number(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  DateTime? _movementDate(dynamic movement) => movement['createdAt'] == null ? null : DateTime.tryParse('${movement['createdAt']}')?.toLocal();

  String _averageDuration() {
    final completed = _tasks.where((task) => task.status == 'COMPLETED' && task.createdAt != null && task.updatedAt != null).toList();
    if (completed.isEmpty) return 'Veri yok';
    final minutes = completed.map((task) => task.updatedAt!.difference(task.createdAt!).inMinutes).reduce((a, b) => a + b) ~/ completed.length;
    return minutes >= 60 ? '${minutes ~/ 60}s ${minutes % 60}dk' : '$minutes dk';
  }

  String _mostActiveWorker() {
    final counts = <String, int>{};
    for (final task in _tasks.where((task) => task.status == 'COMPLETED')) {
      final name = task.assignedWorkerName.trim();
      if (name.isNotEmpty && name != 'Atanmamış') counts[name] = (counts[name] ?? 0) + 1;
    }
    return counts.isEmpty ? 'Veri yok' : counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String _mostUsedShelf() {
    final counts = <String, int>{};
    for (final task in _tasks.where((task) => task.status == 'COMPLETED')) {
      for (final item in task.items) {
        final code = '${item['shelfCode'] ?? ''}'.trim();
        if (code.isNotEmpty) counts[code] = (counts[code] ?? 0) + _number(item['quantity'] ?? 1);
      }
    }
    return counts.isEmpty ? 'Veri yok' : counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
  DateTimeRange _reportRange(ReportPeriod period) {
    final day = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return switch (period) {
      ReportPeriod.daily => DateTimeRange(start: day, end: day),
      ReportPeriod.weekly => DateTimeRange(start: day.subtract(const Duration(days: 6)), end: day),
      ReportPeriod.monthly => DateTimeRange(start: DateTime(day.year, day.month), end: day),
    };
  }

  bool _sameDayOrBetween(DateTime? value, DateTimeRange range) => value != null && !value.isBefore(range.start) && value.isBefore(range.end.add(const Duration(days: 1)));

  ReportSnapshot _createReport(ReportPeriod period) {
    final range = _reportRange(period);


    final tasksInRange = _tasks.where((task) => _sameDayOrBetween(task.updatedAt ?? task.createdAt, range)).toList();
    final movementsInRange = _stockMovements.where((movement) => _sameDayOrBetween(_movementDate(movement), range)).toList();

    return ReportSnapshot(
      period: period,
      title: '${switch (period) { ReportPeriod.daily => 'Günlük', ReportPeriod.weekly => 'Haftalık', ReportPeriod.monthly => 'Aylık' }} Depo Raporu',
      start: range.start,
      end: range.end,
      allProducts: _allProducts,
      allShelves: _shelves,
      tasksInRange: tasksInRange,
      movementsInRange: movementsInRange,
      occupancyRates: _calculateOccupancyRates(),
    );
  }

  Future<void> _exportReport(ReportPeriod period, ReportFormat format) async {
    final report = _createReport(period);
    try {
      if (format == ReportFormat.pdf) { await ReportExportService().exportPdf(report); }
      else { await ReportExportService().exportExcel(report); }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rapor oluşturulamadı.')));
    }
  }

  @override
  void dispose() {
    WebSocketService.instance.unsubscribe(_onLiveEvent);
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _lastUpdated == null) {
      return const Scaffold(backgroundColor: Color(0xFFF7F7FB), body: Center(child: CircularProgressIndicator(color: kAnalyticsPurple)));
    }

    final taskStats = _getWeeklyTaskStats();
    final pendingTasks = _countByStatus(['PENDING']);
    final inProgressTasks = _countByStatus(['ASSIGNED', 'IN_PROGRESS', 'PICKING', 'PROCESSING']);
    final completedTasks = _countByStatus(['COMPLETED']);
    final cancelledTasks = _countByStatus(['CANCELLED', 'DELETED']);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, .035), end: Offset.zero).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic)),
          child: RefreshIndicator(
            color: kAnalyticsPurple,
            onRefresh: _fetchData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildPageHeader(context),
                const SizedBox(height: 24),
                _buildTaskKpis(pendingTasks, inProgressTasks, completedTasks),
                const SizedBox(height: 24),
                LayoutBuilder(builder: (context, constraints) {
                  final compact = constraints.maxWidth < 1100;
                  final taskChart = TaskChart(stats: taskStats);
                  final pie = TaskPieChart(pending: pendingTasks, inProgress: inProgressTasks, completed: completedTasks, cancelled: cancelledTasks);

                  return compact
                      ? Column(children: [taskChart, const SizedBox(height: 20), pie])
                      : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 7, child: taskChart), const SizedBox(width: 20), Expanded(flex: 4, child: pie)]);
                }),
                const SizedBox(height: 20),
                ReportsPanel(onExport: _exportReport),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final narrow = constraints.maxWidth < 720;
    final heading = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Operasyon İstatistikleri', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -.6, color: Color(0xFF1D2230))),
      const SizedBox(height: 5),
      const Text('Saha personelinin görev ve performans analizleri', style: TextStyle(color: Color(0xFF687386), fontSize: 14)),
      const SizedBox(height: 7),
      Text('Son Güncelleme: ${_lastUpdated == null ? '—' : DateFormat('HH:mm:ss').format(_lastUpdated!)}', style: const TextStyle(fontSize: 12, color: Color(0xFF778196))),
    ]);
    final actions = Wrap(spacing: 9, runSpacing: 9, crossAxisAlignment: WrapCrossAlignment.center, children: [
      FilledButton.tonalIcon(onPressed: _fetchData, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Yenile'), style: FilledButton.styleFrom(foregroundColor: kAnalyticsPurple)),
      Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9), decoration: BoxDecoration(color: const Color(0xFF16A36A).withOpacity(.1), borderRadius: BorderRadius.circular(99)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, size: 10, color: Color(0xFF16A36A)), SizedBox(width: 6), Text('LIVE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF12804F)))])),
    ]);
    return narrow ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [heading, const SizedBox(height: 16), actions]) : Row(children: [Expanded(child: heading), actions]);
  });

  Widget _buildTaskKpis(int pending, int inProgress, int completed) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth >= 1000 ? (constraints.maxWidth - 60) / 6 : 218.0;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: width, height: 174, child: KpiCard(title: 'Bekleyen Görev', value: '$pending', icon: Icons.pending_actions_rounded, color: const Color(0xFFF57C00), trendLabel: 'Aktif görev kuyruğu', isPositive: pending == 0, progress: _progress(pending / 20))),
        SizedBox(width: width, height: 174, child: KpiCard(title: 'İşlemdeki Görev', value: '$inProgress', icon: Icons.sync_rounded, color: const Color(0xFF1E88E5), trendLabel: 'Şu anda işleniyor', isPositive: true, progress: _progress(inProgress / 20))),
        SizedBox(width: width, height: 174, child: KpiCard(title: 'Tamamlanan Görev', value: '$completed', icon: Icons.task_alt_rounded, color: const Color(0xFF16A36A), trendLabel: 'Tüm zamanlar', isPositive: true, progress: _progress(completed / max(1, _tasks.length)))),
        SizedBox(width: width, height: 174, child: KpiCard(title: 'En Aktif Personel', value: _mostActiveWorker(), icon: Icons.person_pin_rounded, color: const Color(0xFF1E88E5), trendLabel: 'Tamamlananlara göre', isPositive: true, progress: _progress(_tasks.isEmpty ? 0 : _countWorkerTasks(_mostActiveWorker()) / _tasks.length))),
        SizedBox(width: width, height: 174, child: KpiCard(title: 'En Kullanılan Raf', value: _mostUsedShelf(), icon: Icons.shelves, color: const Color(0xFFF57C00), trendLabel: 'İşlenen miktara göre', isPositive: true, progress: _progress(_tasks.isEmpty ? 0 : 1))),
        SizedBox(width: width, height: 174, child: KpiCard(title: 'Ort. Görev Süresi', value: _averageDuration(), icon: Icons.timer_outlined, color: kAnalyticsPurple, trendLabel: 'Tamamlanan ortalaması', isPositive: true, progress: _progress(_completedDurationMinutes() / 240))),
      ]);
    });
  }

  int _countWorkerTasks(String workerName) => _tasks.where((task) => task.status == 'COMPLETED' && task.assignedWorkerName == workerName).length;
  double _completedDurationMinutes() {
    final completed = _tasks.where((task) => task.status == 'COMPLETED' && task.createdAt != null && task.updatedAt != null).toList();
    if (completed.isEmpty) return 0;
    return completed.map((task) => task.updatedAt!.difference(task.createdAt!).inMinutes).reduce((a, b) => a + b) / completed.length;
  }
  double _progress(num value) => value.clamp(0, 1).toDouble();
}