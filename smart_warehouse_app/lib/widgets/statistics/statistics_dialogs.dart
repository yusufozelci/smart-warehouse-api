import 'package:flutter/material.dart';

class StatisticsDialogs {
  StatisticsDialogs._();

  static Widget _buildDialog({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 950,
        height: 650,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 18,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(.08),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withOpacity(.15),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close),
                  )
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  static Widget _summaryCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // KRİTİK STOK DİYALOĞU
  static Future<void> showCriticalStock({
    required BuildContext context,
    required List<dynamic> products,
  }) {
    return showDialog(
      context: context,
      builder: (_) => _buildDialog(
        context: context,
        title: "Kritik Stok Ürünleri",
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFD93025),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      title: "Kritik Ürün",
                      value: "${products.length}",
                      color: Colors.red,
                      icon: Icons.warning_amber_rounded,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _summaryCard(
                      title: "En Düşük",
                      value: "${products.isNotEmpty ? products.map((e) => e['stockQuantity'] ?? 0).reduce((a, b) => a < b ? a : b) : 0} adet",
                      color: Colors.orange,
                      icon: Icons.trending_down,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _summaryCard(
                      title: "Limit",
                      value: "10 adet",
                      color: Colors.blue,
                      icon: Icons.rule,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: products.isEmpty
                    ? const Center(child: Text("Kritik stokta ürün bulunmamaktadır."))
                    : ListView.separated(
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, index) {
                    final p = products[index];

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Colors.red.shade50,
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFD93025),
                        ),
                      ),
                      title: Text(
                        p['name']?.toString() ?? '-',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("SKU : ${p['sku']?.toString() ?? '-'}"),
                            const SizedBox(height: 4),
                            Text("Raf : ${p['shelfCode']?.toString() ?? '-'}"),
                          ],
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${p['stockQuantity']} adet",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> showShelves({
    required BuildContext context,
    required List<dynamic> shelves,
    required List<dynamic> allProducts,
  }) {
    String searchQuery = "";

    return showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
          builder: (context, setState) {
            final filteredShelves = shelves.where((s) {
              final shelfCode = (s['shelfCode']?.toString() ?? "").toLowerCase();
              return shelfCode.contains(searchQuery.toLowerCase());
            }).toList();
            final int totalShelves = shelves.length;
            int fullShelves = shelves.where((s) {
              return allProducts.any((p) => p['shelfCode'] == s['shelfCode'] && (p['stockQuantity'] ?? 0) > 0);
            }).length;

            final int emptyShelves = totalShelves - fullShelves;

            return _buildDialog(
              context: context,
              title: "Depo Rafları",
              icon: Icons.layers,
              color: const Color(0xFF1967D2),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _summaryCard(
                            title: "Toplam Raf",
                            value: "$totalShelves",
                            color: Colors.blue,
                            icon: Icons.view_module,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _summaryCard(
                            title: "Dolu Raf",
                            value: "$fullShelves",
                            color: Colors.green,
                            icon: Icons.inbox,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _summaryCard(
                            title: "Boş Raf",
                            value: "$emptyShelves",
                            color: Colors.grey,
                            icon: Icons.outbox,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    TextField(
                      decoration: InputDecoration(
                        hintText: "Raf Kodu ile ara... (Örn: F1-A01)",
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    Expanded(
                      child: filteredShelves.isEmpty
                          ? Center(
                        child: Text(
                          shelves.isEmpty
                              ? "Depoda raf bulunamadı."
                              : "Aradığınız kriterde raf bulunamadı.",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                        ),
                      )
                          : ListView.separated(
                        itemCount: filteredShelves.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (_, index) {
                          final shelf = filteredShelves[index];
                          List<dynamic> productsInShelf = allProducts.where((p) => p['shelfCode'] == shelf['shelfCode']).toList();
                          double totalWeight = 0.0;

                          for (var p in productsInShelf) {
                            double qty = (p['stockQuantity'] ?? 0).toDouble();
                            double unitWeight = (p['weight'] ?? 0.0).toDouble();
                            totalWeight += (qty * unitWeight);
                          }

                          final double maxCapacity = 320.0;
                          int percentage = ((totalWeight / maxCapacity) * 100).toInt();
                          if (totalWeight > 0 && percentage == 0) percentage = 1;
                          if (percentage > 100) percentage = 100;

                          final double ratio = percentage / 100;

                          Color progressColor;
                          if (percentage <= 60) {
                            progressColor = Colors.green;
                          } else if (percentage <= 90) {
                            progressColor = Colors.orange;
                          } else {
                            progressColor = Colors.red;
                          }

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: progressColor.withOpacity(0.1),
                              child: Text(
                                "${shelf['floor']?.toString() ?? '-'}",
                                style: TextStyle(
                                  color: progressColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              shelf['shelfCode']?.toString() ?? "-",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${totalWeight.toStringAsFixed(1)} kg / ${maxCapacity.toStringAsFixed(1)} kg kullanılıyor",
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: ratio,
                                      minHeight: 8,
                                      backgroundColor: progressColor.withOpacity(0.2),
                                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: progressColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "%$percentage",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: progressColor,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
      ),
    );
  }
  static Future<void> showGeneralOccupancy({
    required BuildContext context,
    required List<dynamic> shelves,
    required List<dynamic> allProducts,
  }) {
    final double maxShelfCapacity = 320.0;
    final double totalCapacity = shelves.length * maxShelfCapacity;
    double currentTotalWeight = 0.0;
    Map<int, Map<String, double>> floorData = {};
    for (var s in shelves) {
      int floor = (s['floor'] is int) ? s['floor'] : (int.tryParse(s['floor']?.toString() ?? '1') ?? 1);

      if (!floorData.containsKey(floor)) {
        floorData[floor] = {'used': 0.0, 'total': 0.0};
      }
      floorData[floor]!['total'] = floorData[floor]!['total']! + maxShelfCapacity;
    }

    for (var product in allProducts) {
      double totalProdWeight = (product['stockQuantity'] ?? 0).toDouble() * (product['weight'] ?? 0.0).toDouble();

      if (totalProdWeight > 0) {
        currentTotalWeight += totalProdWeight;

        var shelf = shelves.firstWhere((s) => s['shelfCode'] == product['shelfCode'], orElse: () => null);
        if (shelf != null) {
          int floor = shelf['floor'] ?? 1;
          if (floorData.containsKey(floor)) {
            floorData[floor]!['used'] = floorData[floor]!['used']! + totalProdWeight;
          }
        }
      }
    }
    double emptyCapacity = totalCapacity - currentTotalWeight;
    if (emptyCapacity < 0) emptyCapacity = 0;
    final sortedFloors = floorData.keys.toList()..sort();

    return showDialog(
      context: context,
      builder: (_) => _buildDialog(
        context: context,
        title: "Genel Doluluk Durumu",
        icon: Icons.pie_chart_rounded,
        color: const Color(0xFF0F9D58),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      title: "Toplam Kapasite",
                      value: "${totalCapacity.toStringAsFixed(0)} kg",
                      color: Colors.blue,
                      icon: Icons.inventory_2,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _summaryCard(
                      title: "Kullanılan Kapasite",
                      value: "${currentTotalWeight.toStringAsFixed(0)} kg",
                      color: Colors.green,
                      icon: Icons.check_circle_outline,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _summaryCard(
                      title: "Boş Kapasite",
                      value: "${emptyCapacity.toStringAsFixed(0)} kg",
                      color: Colors.grey,
                      icon: Icons.inbox_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              const Text(
                "Kat Bazlı Doluluk Oranları",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: sortedFloors.isEmpty
                    ? Center(
                  child: Text(
                    "Kat verisi bulunamadı.",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
                    : ListView.separated(
                  itemCount: sortedFloors.length,
                  separatorBuilder: (_, __) => const Divider(height: 24),
                  itemBuilder: (_, index) {
                    final int floor = sortedFloors[index];
                    final double fUsed = floorData[floor]!['used']!;
                    final double fTotal = floorData[floor]!['total']!;

                    final double ratio = fTotal > 0 ? (fUsed / fTotal).clamp(0.0, 1.0) : 0.0;
                    int percentage = (ratio * 100).toInt();
                    if (fUsed > 0 && percentage == 0) percentage = 1;
                    Color progressColor;
                    if (percentage <= 60) {
                      progressColor = Colors.blue;
                    } else if (percentage <= 90) {
                      progressColor = Colors.orange;
                    } else {
                      progressColor = Colors.red;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: progressColor.withOpacity(0.1),
                                  child: Text(
                                    "$floor",
                                    style: TextStyle(
                                      color: progressColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "Kat $floor",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              "%$percentage Dolu",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: progressColor,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 12,
                            backgroundColor: progressColor.withOpacity(0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${fUsed.toStringAsFixed(1)} kg / ${fTotal.toStringAsFixed(1)} kg kullanılıyor",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  static Future<void> showTodayStockEntries({
    required BuildContext context,
    required List<dynamic> todayEntries,
    required int yesterdayEntryCount,
  }) {
    final int todayCount = todayEntries.fold<int>(0, (sum, item) {
      final int qty = (item['quantity'] is num) ? (item['quantity'] as num).toInt() : (int.tryParse(item['quantity']?.toString() ?? '0') ?? 0);
      return sum + qty;
    });

    final int diff = todayCount - yesterdayEntryCount;

    final String diffString = diff > 0 ? "+$diff" : "$diff";
    final Color diffColor = diff > 0 ? Colors.green : (diff < 0 ? Colors.red : Colors.grey);
    final IconData diffIcon = diff > 0 ? Icons.trending_up : (diff < 0 ? Icons.trending_down : Icons.trending_flat);

    return showDialog(
      context: context,
      builder: (_) => _buildDialog(
        context: context,
        title: "Bugünkü Stok Girişleri",
        icon: Icons.move_to_inbox,
        color: const Color(0xFF0F9D58),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      title: "Bugünkü Giriş",
                      value: "$todayCount", // Artık 1030 gösterecek
                      color: Colors.blue,
                      icon: Icons.today,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _summaryCard(
                      title: "Dünkü Giriş",
                      value: "$yesterdayEntryCount",
                      color: Colors.orange,
                      icon: Icons.history,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _summaryCard(
                      title: "Fark",
                      value: diffString,
                      color: diffColor,
                      icon: diffIcon,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                "Giriş Hareketleri (Bugün)",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: todayEntries.isEmpty
                    ? Center(
                  child: Text(
                    "Bugün için herhangi bir stok girişi bulunmamaktadır.",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                )
                    : ListView.separated(
                  itemCount: todayEntries.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, index) {
                    final entry = todayEntries[index];

                    final product = entry['product'] ?? {};
                    final String productName = product['name']?.toString() ?? entry['productName']?.toString() ?? 'Bilinmeyen Ürün';
                    final String sku = product['sku']?.toString()
                        ?? product['SKU']?.toString()
                        ?? entry['sku']?.toString()
                        ?? entry['SKU']?.toString()
                        ?? '-';
                    final int quantity = entry['quantity'] ?? 0;

                    String timeStr = "-";
                    if (entry['createdAt'] != null) {
                      try {
                        DateTime dt = DateTime.parse(entry['createdAt']).toLocal();
                        timeStr = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                      } catch (e) {}
                    }

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.withOpacity(0.1),
                        child: const Icon(Icons.arrow_downward, color: Colors.green),
                      ),
                      title: Text(
                        productName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("SKU : $sku"),
                            const SizedBox(height: 4),
                            Text("Saat : $timeStr", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "+$quantity Adet",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  static Future<void> showTodayStockExits({
    required BuildContext context,
    required List<dynamic> todayExits,
    required int yesterdayExitCount,
  }) {
    final int todayCount = todayExits.fold<int>(0, (sum, item) {
      final int qty = (item['quantity'] is num) ? (item['quantity'] as num).toInt() : (int.tryParse(item['quantity']?.toString() ?? '0') ?? 0);
      return sum + qty;
    });

    final int diff = todayCount - yesterdayExitCount;

    final String diffString = diff > 0 ? "+$diff" : "$diff";
    final Color diffColor = diff > 0 ? Colors.green : (diff < 0 ? Colors.red : Colors.grey);
    final IconData diffIcon = diff > 0 ? Icons.trending_up : (diff < 0 ? Icons.trending_down : Icons.trending_flat);

    return showDialog(
      context: context,
      builder: (_) => _buildDialog(
        context: context,
        title: "Bugünkü Stok Çıkışları",
        icon: Icons.outbox_rounded,
        color: const Color(0xFFE53935),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      title: "Bugünkü Çıkış",
                      value: "$todayCount",
                      color: Colors.blue,
                      icon: Icons.today,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _summaryCard(
                      title: "Dünkü Çıkış",
                      value: "$yesterdayExitCount",
                      color: Colors.orange,
                      icon: Icons.history,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _summaryCard(
                      title: "Fark",
                      value: diffString,
                      color: diffColor,
                      icon: diffIcon,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                "Çıkış Hareketleri (Bugün)",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: todayExits.isEmpty
                    ? Center(
                  child: Text(
                    "Bugün için herhangi bir stok çıkışı bulunmamaktadır.",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                )
                    : ListView.separated(
                  itemCount: todayExits.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, index) {
                    final exitItem = todayExits[index];

                    final product = exitItem['product'] ?? {};
                    final String productName = product['name']?.toString() ?? exitItem['productName']?.toString() ?? 'Bilinmeyen Ürün';
                    final String sku = product['sku']?.toString()
                        ?? product['SKU']?.toString()
                        ?? exitItem?['sku']?.toString()
                        ?? exitItem?['SKU']?.toString()
                        ?? '-';
                    final int quantity = exitItem['quantity'] ?? 0;

                    String timeStr = "-";
                    if (exitItem['updatedAt'] != null || exitItem['createdAt'] != null) {
                      try {
                        DateTime dt = DateTime.parse(exitItem['updatedAt'] ?? exitItem['createdAt']).toLocal();
                        timeStr = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                      } catch (e) {}
                    }

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Colors.red.withOpacity(0.1),
                        child: const Icon(Icons.arrow_upward, color: Colors.red),
                      ),
                      title: Text(
                        productName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("SKU : $sku"),
                            const SizedBox(height: 4),
                            Text("Saat : $timeStr", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "-$quantity Adet",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}