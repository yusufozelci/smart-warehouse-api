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
import 'widgets/statistics/recent_task_table.dart';
import 'widgets/statistics/reports_panel.dart';
import 'widgets/statistics/statistics_components.dart';
import 'services/report_export_service.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _isRealtimeRefreshPending = false;
  List<dynamic> _shelves = [];
  List<dynamic> _allProducts = [];
  List<dynamic> _stockMovements = [];
  List<TaskModel> _tasks = [];
  DateTime _selectedDate = DateTime.now();
  DateTime? _lastUpdated;

  late final AnimationController _entranceController;
  late final TabController _tabController;

  String get baseUrl => kIsWeb ? 'http://localhost:8080' : (Platform.isAndroid ? 'http://10.0.2.2:8080' : 'http://localhost:8080');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

      if (shelfRes.statusCode == 200 && prodRes.statusCode == 200) {
        setState(() {
          _shelves = jsonDecode(utf8.decode(shelfRes.bodyBytes));
          _allProducts = jsonDecode(utf8.decode(prodRes.bodyBytes));
          _stockMovements = movementRes.statusCode == 200 ? jsonDecode(utf8.decode(movementRes.bodyBytes)) : [];
          _tasks = tasks;
          _lastUpdated = DateTime.now();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
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

  List<Map<String, dynamic>> _getWeeklyStockMovements() {
    List<Map<String, dynamic>> stats = [];
    DateTime today = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      DateTime date = today.subtract(Duration(days: i));
      String dayLabel = DateFormat('E', 'tr').format(date);
      final movements = _stockMovements.where((movement) => _sameDay(_movementDate(movement), date));
      int dailyEntries = movements.where((movement) => movement['type'] == 'IN').fold(0, (sum, movement) => sum + _number(movement['quantity']));
      int dailyExits = movements.where((movement) => movement['type'] == 'OUT').fold(0, (sum, movement) => sum + _number(movement['quantity']));
      stats.add({'day': dayLabel, 'entries': dailyEntries, 'exits': dailyExits});
    }
    return stats;
  }

  int _countByStatus(Iterable<String> statuses) => _tasks.where((task) => statuses.contains(task.status)).length;
  int _number(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  double _decimal(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  DateTime? _movementDate(dynamic movement) => movement['createdAt'] == null ? null : DateTime.tryParse('${movement['createdAt']}')?.toLocal();
  bool _sameDay(DateTime? first, DateTime second) => first != null && first.year == second.year && first.month == second.month && first.day == second.day;

  Map<String, double> _shelfWeights() {
    final weights = <String, double>{};
    for (final product in _allProducts) {
      final code = product['shelfCode']?.toString();
      if (code != null) weights[code] = (weights[code] ?? 0) + (_number(product['stockQuantity']) * _decimal(product['weight']));
    }
    return weights;
  }

  String _productName(dynamic product) => '${product['name'] ?? product['productName'] ?? product['productCode'] ?? '—'}';

  String _mostStockedProduct() {
    if (_allProducts.isEmpty) return 'Veri yok';
    final product = _allProducts.reduce((a, b) => _number(a['stockQuantity']) >= _number(b['stockQuantity']) ? a : b);
    return _productName(product);
  }

  String _mostExitedProduct() {
    final quantities = <String, int>{};
    for (final task in _tasks.where((task) => task.status == 'COMPLETED')) {
      for (final item in task.items) {
        final name = '${item['productName'] ?? item['name'] ?? item['productCode'] ?? 'Ürün #${item['productId'] ?? '—'}'}';
        quantities[name] = (quantities[name] ?? 0) + _number(item['quantity'] ?? 1);
      }
    }
    if (quantities.isEmpty) return 'Veri yok';
    return quantities.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

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

  int _criticalStockCount() => _allProducts.where((product) => _number(product['stockQuantity']) <= 10).length;

  DateTimeRange _reportRange(ReportPeriod period) {
    final day = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return switch (period) {
      ReportPeriod.daily => DateTimeRange(start: day, end: day),
      ReportPeriod.weekly => DateTimeRange(start: day.subtract(const Duration(days: 6)), end: day),
      ReportPeriod.monthly => DateTimeRange(start: DateTime(day.year, day.month), end: day),
    };
  }

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

  bool _sameDayOrBetween(DateTime? value, DateTimeRange range) => value != null && !value.isBefore(range.start) && value.isBefore(range.end.add(const Duration(days: 1)));

  Future<void> _exportReport(ReportPeriod period, ReportFormat format) async {
    final report = _createReport(period);
    try {
      if (format == ReportFormat.pdf) {
        await ReportExportService().exportPdf(report);
      } else {
        await ReportExportService().exportExcel(report);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rapor oluşturulamadı. Lütfen tekrar deneyin.')));
    }
  }

  @override
  void dispose() {
    WebSocketService.instance.unsubscribe(_onLiveEvent);
    _entranceController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _lastUpdated == null) {
      return const Scaffold(backgroundColor: Color(0xFFF7F7FB), body: Center(child: CircularProgressIndicator(color: kAnalyticsPurple)));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, .035), end: Offset.zero).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
                child: _buildPageHeader(context),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: kAnalyticsPurple,
                    labelColor: kAnalyticsPurple,
                    unselectedLabelColor: const Color(0xFF687386),
                    labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: const [
                      Tab(text: "Stok & Kapasite Durumu", icon: Icon(Icons.inventory_2_outlined)),
                      Tab(text: "Görev & Operasyon Yönetimi", icon: Icon(Icons.group_work_outlined)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStockTab(),
                    _buildTaskTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockTab() {
    final occupancy = _calculateOccupancyRates();
    final stockStats = _getWeeklyStockMovements();
    final totalProducts = _allProducts.length;

    final today = stockStats.isEmpty ? <String, dynamic>{'entries': 0, 'exits': 0} : stockStats.last;
    final yesterday = stockStats.length < 2 ? <String, dynamic>{'entries': 0, 'exits': 0} : stockStats[stockStats.length - 2];

    final shelfWeights = _shelfWeights();
    final usedWeight = shelfWeights.values.fold<double>(0, (sum, value) => sum + value);
    final emptyShelves = _shelves.where((s) => (shelfWeights['${s['shelfCode'] ?? s['id']}'] ?? 0) == 0).length;
    final fullestShelf = _shelves.isEmpty ? 'Veri yok' : _shelves.map((s) => '${s['shelfCode'] ?? s['id']}').reduce((a, b) => (shelfWeights[a] ?? 0) >= (shelfWeights[b] ?? 0) ? a : b);
    final fullestFloor = ['kat1', 'kat2', 'kat3'].reduce((a, b) => (occupancy[a] ?? 0) >= (occupancy[b] ?? 0) ? a : b).replaceFirst('kat', 'Kat ');

    return RefreshIndicator(
      color: kAnalyticsPurple,
      onRefresh: _fetchData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: Column(
          children: [
            _buildStockKpis(totalProducts, occupancy['genel'] ?? 0, today, yesterday),
            const SizedBox(height: 24),
            LayoutBuilder(builder: (context, constraints) {
              final compact = constraints.maxWidth < 1100;
              final stockChart = StockChart(stats: stockStats);
              final occupancyCard = OccupancyCard(occupancy: occupancy, shelfCount: _shelves.length, usedWeight: usedWeight);
              return compact
                  ? Column(children: [stockChart, const SizedBox(height: 20), occupancyCard])
                  : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 7, child: stockChart), const SizedBox(width: 20), Expanded(flex: 5, child: occupancyCard)]);
            }),
            const SizedBox(height: 20),
            LayoutBuilder(builder: (context, constraints) {
              final compact = constraints.maxWidth < 1100;
              final quickInfo = QuickInfoCard(items: [
                QuickInfo('En çok stok giren ürün', _mostStockedProduct(), Icons.south_rounded, const Color(0xFF16A36A)),
                QuickInfo('En çok stok çıkan ürün', _mostExitedProduct(), Icons.north_rounded, const Color(0xFFE53935)),
                QuickInfo('Boş raf sayısı', '$emptyShelves raf', Icons.shelves, const Color(0xFF4285F4)),
                QuickInfo('En dolu raf', fullestShelf, Icons.inventory_rounded, const Color(0xFFFF9800)),
                QuickInfo('En dolu kat', fullestFloor, Icons.layers_outlined, const Color(0xFF00A896)),
              ]);
              final reports = ReportsPanel(onExport: _exportReport);

              return compact
                  ? Column(children: [quickInfo, const SizedBox(height: 20), reports])
                  : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 1, child: quickInfo), const SizedBox(width: 20), Expanded(flex: 1, child: reports)]);
            }),
          ],
        ),
      ),
    );
  }
  Widget _buildTaskTab() {
    final taskStats = _getWeeklyTaskStats();
    final pendingTasks = _countByStatus(['PENDING']);
    final inProgressTasks = _countByStatus(['ASSIGNED', 'IN_PROGRESS', 'PICKING', 'PROCESSING']);
    final completedTasks = _countByStatus(['COMPLETED']);
    final cancelledTasks = _countByStatus(['CANCELLED', 'DELETED']);

    return RefreshIndicator(
      color: kAnalyticsPurple,
      onRefresh: _fetchData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: Column(
          children: [
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
            RecentTaskTable(tasks: ([..._tasks]..sort((a, b) => (b.updatedAt ?? b.createdAt ?? DateTime(0)).compareTo(a.updatedAt ?? a.createdAt ?? DateTime(0))))),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final narrow = constraints.maxWidth < 720;
    final heading = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Warehouse Analytics', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -.6, color: Color(0xFF1D2230))),
      const SizedBox(height: 5),
      const Text('Gerçek zamanlı depo performans analizi', style: TextStyle(color: Color(0xFF687386), fontSize: 14)),
      const SizedBox(height: 7),
      Text('Son Güncelleme: ${_lastUpdated == null ? '—' : DateFormat('HH:mm:ss').format(_lastUpdated!)}', style: const TextStyle(fontSize: 12, color: Color(0xFF778196))),
    ]);
    final actions = Wrap(spacing: 9, runSpacing: 9, crossAxisAlignment: WrapCrossAlignment.center, children: [
      OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_month_outlined, size: 18), label: Text(DateFormat('dd MMM yyyy', 'tr').format(_selectedDate))),
      FilledButton.tonalIcon(onPressed: _fetchData, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Yenile'), style: FilledButton.styleFrom(foregroundColor: kAnalyticsPurple)),
      Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9), decoration: BoxDecoration(color: const Color(0xFF16A36A).withOpacity(.1), borderRadius: BorderRadius.circular(99)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, size: 10, color: Color(0xFF16A36A)), SizedBox(width: 6), Text('LIVE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF12804F)))])),
    ]);
    return narrow ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [heading, const SizedBox(height: 16), actions]) : Row(children: [Expanded(child: heading), actions]);
  });

  Widget _buildStockKpis(int totalProducts, double occupancy, Map<String, dynamic> today, Map<String, dynamic> yesterday) {
    final totalShelves = _shelves.length;
    final totalItemsInStock = _allProducts.fold<int>(0, (sum, p) => sum + _number(p['stockQuantity']));
    final entries = _number(today['entries']);
    final exits = _number(today['exits']);
    final previousEntries = _number(yesterday['entries']);
    final previousExits = _number(yesterday['exits']);

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth >= 1000 ? (constraints.maxWidth - 60) / 6 : 218.0;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: width, height: 174, child: KpiCard(title: 'Toplam Ürün', value: '$totalProducts', icon: Icons.inventory_2_rounded, color: kAnalyticsPurple, trendLabel: '$totalItemsInStock adet stokta', isPositive: true, progress: _progress(totalProducts == 0 ? 0 : totalItemsInStock / (totalProducts * 100)))),
        SizedBox(width: width, height: 174, child: KpiCard(title: 'Toplam Raf', value: '$totalShelves', icon: Icons.shelves, color: const Color(0xFF4285F4), trendLabel: 'Kapasite ${totalShelves * 320} kg', isPositive: true, progress: _progress(totalShelves / 100))),
        SizedBox(width: width, height: 174, child: KpiCard(title: 'Genel Doluluk', value: '%${occupancy.toStringAsFixed(1)}', icon: Icons.pie_chart_rounded, color: const Color(0xFF8E24AA), trendLabel: 'Kapasite kullanımı', isPositive: occupancy <= 80, progress: occupancy / 100)),
        SizedBox(width: width, height: 174, child: KpiCard(title: 'Kritik Stok', value: '${_criticalStockCount()}', icon: Icons.warning_amber_rounded, color: const Color(0xFFD93025), trendLabel: '10 adet ve altı ürünler', isPositive: _criticalStockCount() == 0, progress: _progress(_criticalStockCount() / max(1, _allProducts.length)))),
        SizedBox(width: width, height: 174, child: KpiCard(title: 'Bugünkü Stok Girişi', value: '$entries', icon: Icons.move_to_inbox_rounded, color: const Color(0xFF00A896), trendLabel: _trendText(entries, previousEntries), isPositive: entries >= previousEntries, progress: _progress(entries / 100))),
        SizedBox(width: width, height: 174, child: KpiCard(title: 'Bugünkü Stok Çıkışı', value: '$exits', icon: Icons.outbox_rounded, color: const Color(0xFFE53935), trendLabel: _trendText(exits, previousExits), isPositive: exits <= previousExits, progress: _progress(exits / 100))),
      ]);
    });
  }

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

  String _trendText(int value, int previous) {
    if (previous == 0) return 'Düne göre yeni kayıt';
    final change = ((value - previous).abs() / previous * 100).round();
    return 'Düne göre %$change ${value >= previous ? 'artış' : 'azalış'}';
  }

  double _progress(num value) => value.clamp(0, 1).toDouble();

  Future<void> _pickDate() async {
    final selected = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (selected != null && mounted) setState(() => _selectedDate = selected);
  }
}