import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/task_model.dart';
import '../widgets/statistics/reports_panel.dart';

class ReportSnapshot {
  const ReportSnapshot({
    required this.period,
    required this.title,
    required this.start,
    required this.end,
    required this.allProducts,
    required this.allShelves,
    required this.tasksInRange,
    required this.movementsInRange,
    required this.occupancyRates,
  });

  final ReportPeriod period;
  final String title;
  final DateTime start;
  final DateTime end;
  final List<dynamic> allProducts;
  final List<dynamic> allShelves;
  final List<TaskModel> tasksInRange;
  final List<dynamic> movementsInRange;
  final Map<String, double> occupancyRates;
}

class ReportExportService {
  Future<void> exportPdf(ReportSnapshot report) async {
    final document = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();
    final lightFont = await PdfGoogleFonts.robotoMedium();

    document.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (context) => _buildCorporateHeader(report, boldFont, lightFont),
      footer: (context) => _buildPdfFooter(context, font),
      build: (context) {
        switch (report.period) {
          case ReportPeriod.daily:
            return _buildDailyPdfLayout(report, boldFont, font);
          case ReportPeriod.weekly:
            return _buildWeeklyPdfLayout(report, boldFont, font);
          case ReportPeriod.monthly:
            return _buildMonthlyPdfLayout(report, boldFont, font);
        }
      },
    ));
    await Printing.layoutPdf(onLayout: (format) async => document.save());
  }

  List<pw.Widget> _buildDailyPdfLayout(ReportSnapshot report, pw.Font bold, pw.Font regular) {
    int totalProducts = report.allProducts.length;
    int totalShelves = report.allShelves.length;
    int activeWorkers = report.tasksInRange.map((t) => t.assignedWorkerName).toSet().length;
    int emptyShelves = totalShelves - _getUsedShelves(report.allProducts).length;

    int stockIn = _sumMovements(report.movementsInRange, 'IN');
    int stockOut = _sumMovements(report.movementsInRange, 'OUT');
    int newProducts = report.allProducts.where((p) => _isSameDay(DateTime.tryParse(p['createdAt'] ?? ''), report.start)).length;
    int critical = report.allProducts.where((p) => _num(p['stockQuantity']) <= 10).length;

    int created = report.tasksInRange.length;
    int completed = report.tasksInRange.where((t) => t.status == 'COMPLETED').length;
    int pending = report.tasksInRange.where((t) => t.status == 'PENDING').length;
    int inProgress = report.tasksInRange.where((t) => t.status == 'IN_PROGRESS' || t.status == 'ASSIGNED').length;
    int cancelled = report.tasksInRange.where((t) => t.status == 'CANCELLED' || t.status == 'DELETED').length;

    return [
      _sectionTitle('Genel Durum', bold),
      _buildTable(['Metrik', 'Değer'], [
        ['Toplam Ürün', '$totalProducts'],
        ['Toplam Raf', '$totalShelves'],
        ['Genel Doluluk', '%${(report.occupancyRates['genel'] ?? 0).toStringAsFixed(1)}'],
        ['Boş Raf', '$emptyShelves'],
        ['Aktif Personel', '$activeWorkers'],
      ], bold, regular),

      pw.SizedBox(height: 16),
      pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Stok Hareketleri', bold),
                    _buildTable(['İşlem', 'Miktar'], [
                      ['Stok Girişi', '$stockIn Ürün'],
                      ['Stok Çıkışı', '$stockOut Ürün'],
                      ['Yeni Ürün Kaydı', '$newProducts'],
                      ['Kritik Stoğa Düşen', '$critical'],
                    ], bold, regular),
                  ]
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Görev Durumu', bold),
                    _buildTable(['Durum', 'Sayı'], [
                      ['Oluşturulan', '$created'],
                      ['Tamamlanan', '$completed'],
                      ['Devam Eden', '$inProgress'],
                      ['Bekleyen', '$pending'],
                      ['İptal Edilen', '$cancelled'],
                    ], bold, regular),
                  ]
              ),
            )
          ]
      ),

      pw.SizedBox(height: 16),
      _sectionTitle('En Çok İşlem Gören Ürünler', bold),
      _buildTable(['Ürün', 'İşlem Hacmi (Adet)'], _getTopProducts(report, 5), bold, regular),

      pw.SizedBox(height: 16),
      pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('En Yoğun Personeller', bold),
                    _buildTable(['Personel', 'Tamamlanan Görev'], _getTopWorkers(report, 3), bold, regular),
                  ]
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Raf Doluluk Oranı', bold),
                    _buildTable(['Kat', 'Doluluk'], [
                      ['Kat 1', '%${(report.occupancyRates['kat1'] ?? 0).toStringAsFixed(1)}'],
                      ['Kat 2', '%${(report.occupancyRates['kat2'] ?? 0).toStringAsFixed(1)}'],
                      ['Kat 3', '%${(report.occupancyRates['kat3'] ?? 0).toStringAsFixed(1)}'],
                    ], bold, regular),
                  ]
              ),
            )
          ]
      ),
    ];
  }
  List<pw.Widget> _buildWeeklyPdfLayout(ReportSnapshot report, pw.Font bold, pw.Font regular) {
    int stockIn = _sumMovements(report.movementsInRange, 'IN');
    int stockOut = _sumMovements(report.movementsInRange, 'OUT');
    int created = report.tasksInRange.length;
    int completed = report.tasksInRange.where((t) => t.status == 'COMPLETED').length;
    int cancelled = report.tasksInRange.where((t) => t.status == 'CANCELLED' || t.status == 'DELETED').length;

    return [
      _sectionTitle('Haftalık Özet', bold),
      _buildTable(['Metrik', 'Değer'], [
        ['Toplam Giriş', '$stockIn'],
        ['Toplam Çıkış', '$stockOut'],
        ['Oluşturulan Görev', '$created'],
        ['Tamamlanan Görev', '$completed'],
        ['İptal Edilen', '$cancelled'],
      ], bold, regular),

      pw.SizedBox(height: 16),
      pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Günlük Görev Dağılımı', bold),
                    _buildTable(['Gün', 'Oluşturulan', 'Tamamlanan'], _getDailyTaskDistribution(report), bold, regular),
                  ]
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Günlük Stok Hareketi', bold),
                    _buildTable(['Gün', 'Giriş', 'Çıkış'], _getDailyStockDistribution(report), bold, regular),
                  ]
              ),
            )
          ]
      ),

      pw.SizedBox(height: 16),
      _sectionTitle('En Çok Hareket Gören Raflar', bold),
      _buildTable(['Raf', 'İşlem Hacmi'], _getTopShelves(report, 5), bold, regular),

      pw.SizedBox(height: 16),
      _sectionTitle('Personel Performansı', bold),
      _buildTable(['Personel', 'Görev Sayısı', 'Ortalama Süre (Dk)'], _getWorkerPerformanceAdvanced(report), bold, regular),
    ];
  }
  List<pw.Widget> _buildMonthlyPdfLayout(ReportSnapshot report, pw.Font bold, pw.Font regular) {
    int totalProducts = report.allProducts.length;
    int created = report.tasksInRange.length;
    int completed = report.tasksInRange.where((t) => t.status == 'COMPLETED').length;
    int cancelled = report.tasksInRange.where((t) => t.status == 'CANCELLED' || t.status == 'DELETED').length;

    int stockIn = _sumMovements(report.movementsInRange, 'IN');
    int stockOut = _sumMovements(report.movementsInRange, 'OUT');
    int net = stockIn - stockOut;
    String netPrefix = net > 0 ? "+" : "";

    return [
      _sectionTitle('Genel İstatistikler', bold),
      _buildTable(['Metrik', 'Değer'], [
        ['Toplam Ürün Çeşidi', '$totalProducts'],
        ['Toplam Görev', '$created'],
        ['Tamamlanan Görev', '$completed'],
        ['İptal Edilen', '$cancelled'],
      ], bold, regular),

      pw.SizedBox(height: 16),
      pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Stok Hareketleri', bold),
                    _buildTable(['İşlem', 'Değer'], [
                      ['Toplam Giriş', '$stockIn'],
                      ['Toplam Çıkış', '$stockOut'],
                      ['Net Artış', '$netPrefix$net'],
                    ], bold, regular),
                  ]
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Depo Kullanımı', bold),
                    _buildTable(['Kat', 'Ortalama Doluluk'], [
                      ['Kat 1', '%${(report.occupancyRates['kat1'] ?? 0).toStringAsFixed(1)}'],
                      ['Kat 2', '%${(report.occupancyRates['kat2'] ?? 0).toStringAsFixed(1)}'],
                      ['Kat 3', '%${(report.occupancyRates['kat3'] ?? 0).toStringAsFixed(1)}'],
                      ['GENEL ORTALAMA', '%${(report.occupancyRates['genel'] ?? 0).toStringAsFixed(1)}'],
                    ], bold, regular),
                  ]
              ),
            )
          ]
      ),

      pw.SizedBox(height: 16),
      _sectionTitle('En Çok İşlem Gören Ürünler (İlk 10)', bold),
      _buildTable(['Sıralama', 'Ürün Adı', 'İşlem Hacmi (Adet)'], _getTopProductsRanked(report, 10), bold, regular),

      pw.SizedBox(height: 16),
      _sectionTitle('En Başarılı Personeller', bold),
      _buildTable(['Personel', 'Tamamlanan Görev'], _getTopWorkers(report, 10), bold, regular),
    ];
  }

  Future<void> exportExcel(ReportSnapshot report) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    switch (report.period) {
      case ReportPeriod.daily: _buildDailyExcel(excel, report); break;
      case ReportPeriod.weekly: _buildWeeklyExcel(excel, report); break;
      case ReportPeriod.monthly: _buildMonthlyExcel(excel, report); break;
    }

    final bytes = excel.encode();
    if (bytes != null) {
      await FileSaver.instance.saveFile(name: _fileName(report), bytes: Uint8List.fromList(bytes), ext: 'xlsx', mimeType: MimeType.microsoftExcel);
    }
  }

  void _buildDailyExcel(Excel excel, ReportSnapshot report) {
    final sheet = excel['Günlük Rapor'];
    _addExcelHeader(sheet, report);

    int emptyShelves = report.allShelves.length - _getUsedShelves(report.allProducts).length;
    _addExcelTable(sheet, ['Genel Durum', 'Değer'], [
      ['Toplam Ürün', report.allProducts.length],
      ['Toplam Raf', report.allShelves.length],
      ['Genel Doluluk', '%${(report.occupancyRates['genel'] ?? 0).toStringAsFixed(1)}'],
      ['Boş Raf', emptyShelves],
    ]);
    sheet.appendRow([TextCellValue('')]);

    _addExcelTable(sheet, ['Stok Hareketleri', 'Miktar'], [
      ['Stok Girişi', _sumMovements(report.movementsInRange, 'IN')],
      ['Stok Çıkışı', _sumMovements(report.movementsInRange, 'OUT')],
    ]);
    sheet.appendRow([TextCellValue('')]);

    _addExcelTable(sheet, ['En Çok İşlem Gören Ürünler', 'Miktar'], _getTopProducts(report, 10));
    sheet.appendRow([TextCellValue('')]);

    _addExcelTable(sheet, ['En Yoğun Personeller', 'Tamamlanan Görev'], _getTopWorkers(report, 10));
  }

  void _buildWeeklyExcel(Excel excel, ReportSnapshot report) {
    final sheet = excel['Haftalık Rapor'];
    _addExcelHeader(sheet, report);

    _addExcelTable(sheet, ['Haftalık Özet', 'Değer'], [
      ['Toplam Giriş', _sumMovements(report.movementsInRange, 'IN')],
      ['Toplam Çıkış', _sumMovements(report.movementsInRange, 'OUT')],
      ['Oluşturulan Görev', report.tasksInRange.length],
      ['Tamamlanan Görev', report.tasksInRange.where((t) => t.status == 'COMPLETED').length],
    ]);
    sheet.appendRow([TextCellValue('')]);

    _addExcelTable(sheet, ['Gün', 'Oluşturulan', 'Tamamlanan'], _getDailyTaskDistribution(report));
    sheet.appendRow([TextCellValue('')]);

    _addExcelTable(sheet, ['Gün', 'Giriş', 'Çıkış'], _getDailyStockDistribution(report));
    sheet.appendRow([TextCellValue('')]);

    _addExcelTable(sheet, ['Personel', 'Görev', 'Ortalama Süre (dk)'], _getWorkerPerformanceAdvanced(report));
  }

  void _buildMonthlyExcel(Excel excel, ReportSnapshot report) {
    final sheet = excel['Aylık Rapor'];
    _addExcelHeader(sheet, report);

    int stockIn = _sumMovements(report.movementsInRange, 'IN');
    int stockOut = _sumMovements(report.movementsInRange, 'OUT');

    _addExcelTable(sheet, ['Aylık Özet', 'Değer'], [
      ['Toplam Ürün Çeşidi', report.allProducts.length],
      ['Toplam Görev', report.tasksInRange.length],
      ['Toplam Giriş', stockIn],
      ['Toplam Çıkış', stockOut],
      ['Net Artış', (stockIn - stockOut)],
      ['Depo Genel Doluluk', '%${(report.occupancyRates['genel'] ?? 0).toStringAsFixed(1)}'],
    ]);
    sheet.appendRow([TextCellValue('')]);

    _addExcelTable(sheet, ['Sıra', 'Ürün Adı', 'İşlem Hacmi'], _getTopProductsRanked(report, 50));
    sheet.appendRow([TextCellValue('')]);

    _addExcelTable(sheet, ['Personel', 'Tamamlanan Görev'], _getTopWorkers(report, 50));
  }
  pw.Widget _sectionTitle(String title, pw.Font boldFont) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(title, style: pw.TextStyle(font: boldFont, fontSize: 13, color: const PdfColor.fromInt(0xFF1D2230))),
    );
  }

  pw.Widget _buildTable(List<String> headers, List<List<String>> rows, pw.Font boldFont, pw.Font regularFont) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows.isEmpty ? [List.filled(headers.length, '-')] : rows,
      headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF303746)),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
      cellStyle: pw.TextStyle(font: regularFont, fontSize: 9, color: PdfColors.grey800),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      cellAlignment: pw.Alignment.centerLeft,
      oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF9FAFB)),
      border: null,
    );
  }

  void _addExcelHeader(Sheet sheet, ReportSnapshot report) {
    var titleCell = sheet.cell(CellIndex.indexByString("A1"));
    titleCell.value = TextCellValue(report.title.toUpperCase());
    titleCell.cellStyle = CellStyle(bold: true, fontSize: 14, fontColorHex: ExcelColor.blue);
    sheet.appendRow([TextCellValue('Dönem'), TextCellValue('${_date(report.start)} - ${_date(report.end)}')]);
    sheet.appendRow([TextCellValue('')]);
  }

  void _addExcelTable(Sheet sheet, List<String> headers, List<List<dynamic>> rows) {
    final headerStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.grey200);
    List<CellValue> headerCells = headers.map((h) => TextCellValue(h)).toList();
    sheet.appendRow(headerCells);

    int lastRowIdx = sheet.maxRows - 1;
    for (int col = 0; col < headers.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: lastRowIdx)).cellStyle = headerStyle;
    }

    for (final row in rows) {
      sheet.appendRow(row.map((value) => value is int ? IntCellValue(value) : TextCellValue('$value')).toList());
    }
  }

  pw.Widget _buildCorporateHeader(ReportSnapshot report, pw.Font boldFont, pw.Font lightFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(color: const PdfColor.fromInt(0xFF1E1E2D), borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(report.title.toUpperCase(), style: pw.TextStyle(font: boldFont, fontSize: 16, color: PdfColors.white, letterSpacing: 1)),
              pw.SizedBox(height: 4),
              pw.Text('Rapor Dönemi: ${_date(report.start)} - ${_date(report.end)}', style: pw.TextStyle(font: lightFont, fontSize: 9, color: PdfColors.grey300)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('SMART WAREHOUSE INC.', style: pw.TextStyle(font: boldFont, fontSize: 12, color: PdfColors.white)),
              pw.SizedBox(height: 2),
              pw.Text('Oluşturulma: ${_date(DateTime.now())}', style: pw.TextStyle(font: lightFont, fontSize: 8, color: PdfColors.grey400)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfFooter(pw.Context context, pw.Font font) {
    return pw.Container(
        alignment: pw.Alignment.center,
        margin: const pw.EdgeInsets.only(top: 10),
        padding: const pw.EdgeInsets.only(top: 8),
        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Sistem tarafından otomatik oluşturulmuştur.', style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey500)),
              pw.Text('Sayfa ${context.pageNumber} / ${context.pagesCount}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
            ]
        )
    );
  }

  int _num(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  String _date(DateTime date) => DateFormat('dd.MM.yyyy').format(date);
  String _fileName(ReportSnapshot report) => report.title.toLowerCase().replaceAll(' ', '_').replaceAll('ı', 'i');
  bool _isSameDay(DateTime? first, DateTime second) => first != null && first.year == second.year && first.month == second.month && first.day == second.day;

  int _sumMovements(List<dynamic> movements, String type) {
    return movements.where((m) => m['type'] == type).fold(0, (sum, m) => sum + _num(m['quantity']));
  }

  Set<String> _getUsedShelves(List<dynamic> products) {
    return products.map((p) => p['shelfCode']?.toString() ?? '').where((s) => s.isNotEmpty).toSet();
  }

  List<List<String>> _getTopProducts(ReportSnapshot report, int limit) {
    Map<String, int> counts = {};
    for (var task in report.tasksInRange.where((t) => t.status == 'COMPLETED')) {
      for (var item in task.items) {
        String name = item['productName'] ?? item['name'] ?? 'Bilinmeyen';
        counts[name] = (counts[name] ?? 0) + _num(item['quantity'] ?? 1);
      }
    }
    var sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => [e.key, e.value.toString()]).toList();
  }

  List<List<String>> _getTopProductsRanked(ReportSnapshot report, int limit) {
    var raw = _getTopProducts(report, limit);
    List<List<String>> ranked = [];
    for (int i = 0; i < raw.length; i++) {
      ranked.add([(i + 1).toString(), raw[i][0], raw[i][1]]);
    }
    return ranked;
  }

  List<List<String>> _getTopWorkers(ReportSnapshot report, int limit) {
    Map<String, int> counts = {};
    for (var task in report.tasksInRange.where((t) => t.status == 'COMPLETED')) {
      String name = task.assignedWorkerName.trim();
      if (name.isNotEmpty && name != 'Atanmamış') {
        counts[name] = (counts[name] ?? 0) + 1;
      }
    }
    var sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => [e.key, e.value.toString()]).toList();
  }

  List<List<String>> _getTopShelves(ReportSnapshot report, int limit) {
    Map<String, int> counts = {};
    for (var task in report.tasksInRange.where((t) => t.status == 'COMPLETED')) {
      for (var item in task.items) {
        String shelf = item['shelfCode']?.toString().trim() ?? '';
        if (shelf.isNotEmpty) counts[shelf] = (counts[shelf] ?? 0) + _num(item['quantity'] ?? 1);
      }
    }
    var sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => [e.key, e.value.toString()]).toList();
  }

  List<List<String>> _getWorkerPerformanceAdvanced(ReportSnapshot report) {
    Map<String, List<int>> workerTimes = {};
    for (var task in report.tasksInRange.where((t) => t.status == 'COMPLETED' && t.createdAt != null && t.updatedAt != null)) {
      String name = task.assignedWorkerName.trim();
      if (name.isNotEmpty && name != 'Atanmamış') {
        int duration = task.updatedAt!.difference(task.createdAt!).inMinutes;
        if (!workerTimes.containsKey(name)) workerTimes[name] = [];
        workerTimes[name]!.add(duration);
      }
    }
    var sorted = workerTimes.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
    return sorted.take(10).map((e) {
      int avg = e.value.isEmpty ? 0 : (e.value.reduce((a, b) => a + b) ~/ e.value.length);
      return [e.key, e.value.length.toString(), avg.toString()];
    }).toList();
  }

  List<List<String>> _getDailyTaskDistribution(ReportSnapshot report) {
    List<List<String>> rows = [];
    DateTime current = report.start;
    final formatter = DateFormat('E', 'tr');
    while (!current.isAfter(report.end)) {
      String dayName = formatter.format(current);
      int created = report.tasksInRange.where((t) => _isSameDay(t.createdAt, current)).length;
      int completed = report.tasksInRange.where((t) => t.status == 'COMPLETED' && _isSameDay(t.updatedAt, current)).length;
      rows.add([dayName, created.toString(), completed.toString()]);
      current = current.add(const Duration(days: 1));
    }
    return rows;
  }

  List<List<String>> _getDailyStockDistribution(ReportSnapshot report) {
    List<List<String>> rows = [];
    DateTime current = report.start;
    final formatter = DateFormat('E', 'tr');
    while (!current.isAfter(report.end)) {
      String dayName = formatter.format(current);
      var dailyMovements = report.movementsInRange.where((m) => _isSameDay(DateTime.tryParse(m['createdAt'] ?? ''), current)).toList();
      int sIn = _sumMovements(dailyMovements, 'IN');
      int sOut = _sumMovements(dailyMovements, 'OUT');
      rows.add([dayName, sIn.toString(), sOut.toString()]);
      current = current.add(const Duration(days: 1));
    }
    return rows;
  }
}