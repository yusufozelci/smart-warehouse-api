import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:smart_warehouse_app/services/stock_movement_service.dart';
import 'services/websocket_service.dart';
import 'global_utils.dart';
import 'models/stock_movement_model.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  List<dynamic> _products = [];
  List<dynamic> _shelves = [];
  bool _isLoading = true;
  late Future<List<StockMovementModel>> _movementsFuture;

  String get baseUrl => kIsWeb ? "http://localhost:8080" : (Platform.isAndroid ? "http://10.0.2.2:8080" : "http://localhost:8080");
  final Color primaryColor = const Color(0xFF1A237E);

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _refreshMovements();
    WebSocketService.instance.subscribe(_onWebSocketEvent);
  }

  void _onWebSocketEvent(Map<String, dynamic> data) {
    if (mounted) {
      _fetchProducts();
      _refreshMovements();
    }
  }

  @override
  void dispose() {
    WebSocketService.instance.unsubscribe(_onWebSocketEvent);
    super.dispose();
  }

  void _refreshMovements() {
    setState(() {
      _movementsFuture = StockMovementService().getMovements();
    });
  }

  Future<void> _sendErrorToBackend(String errorMessage) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    try {
      await http.post(
        Uri.parse('$baseUrl/api/admin/logs'),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token"
        },
        body: jsonEncode({
          "message": errorMessage,
          "stackTrace": "inventory_page.dart - Raf Kapasite Kontrolü (Flutter Frontend)"
        }),
      );
    } catch (e) {
      debugPrint("Frontend hatası sunucuya iletilemedi: $e");
    }
  }

  Future<void> _fetchProducts() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final headers = {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token"
      };

      final shelfRes = await http.get(Uri.parse('$baseUrl/api/v1/shelves'), headers: headers);
      if (shelfRes.statusCode == 200) {
        _shelves = jsonDecode(shelfRes.body);
      }

      final response = await http.get(Uri.parse('$baseUrl/api/v1/products'), headers: headers);

      if (response.statusCode == 200) {
        setState(() {
          _products = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Veriler yüklenirken hata oluştu: ${response.statusCode}")),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Stok Ekleme, Azaltma ve Silme Metotları (Mevcut kodlarınla aynı)...
  void _showIncreaseStockDialog(Map<String, dynamic> product) {
    final qtyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${product['name']} - Stok Ekle", style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Mevcut Stok: ${product['stockQuantity']} Adet", style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 10),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Eklenecek Miktar (Adet)", border: OutlineInputBorder()),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              int addedQty = int.tryParse(qtyCtrl.text) ?? 0;
              if (addedQty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen geçerli bir miktar girin.")));
                return;
              }

              double unitWeight = (product['weight'] ?? 0.0).toDouble();
              double addedWeight = unitWeight * addedQty;
              String targetShelfCode = product['shelfCode'] ?? "";

              double currentShelfWeight = 0.0;
              for (var p in _products) {
                if (p['shelfCode'] == targetShelfCode) {
                  currentShelfWeight += (p['stockQuantity'] ?? 0).toDouble() * (p['weight'] ?? 0.0).toDouble();
                }
              }
              if (currentShelfWeight + addedWeight > 320.0) {
                String errorMsg = "Raf kapasitesi (320 kg) aşılıyor!\nMevcut: ${currentShelfWeight.toStringAsFixed(1)} kg | İstenen: ${addedWeight.toStringAsFixed(1)} kg";
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red, duration: const Duration(seconds: 4)));
                _sendErrorToBackend(errorMsg);
                return;
              }

              Navigator.pop(context);
              SharedPreferences prefs = await SharedPreferences.getInstance();
              String? token = prefs.getString('token');

              try {
                final response = await http.put(
                  Uri.parse('$baseUrl/api/v1/products/${product['id']}/increase?amount=$addedQty'),
                  headers: {"Content-Type": "application/json", if (token != null) "Authorization": "Bearer $token"},
                );

                if (response.statusCode == 200) {
                  showGlobalNotification("Stok başarıyla eklendi!");
                  _fetchProducts();
                  _refreshMovements(); // İşlem sonrası logları da yenile
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: ${response.statusCode} - ${response.body}")));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bağlantı hatası!")));
              }
            },
            child: const Text("Stok Ekle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Future<void> _decreaseStock(int id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.put(
      Uri.parse('$baseUrl/api/v1/products/$id/decrease?amount=1'),
      headers: {"Content-Type": "application/json", if (token != null) "Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      _fetchProducts();
      _refreshMovements(); // Logları yenile
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("İşlem Başarısız: ${response.body}"), backgroundColor: Colors.red.shade600));
    }
  }

  Future<void> _deleteProduct(int id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/v1/products/$id'),
        headers: {"Content-Type": "application/json", if (token != null) "Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        showGlobalNotification("Ürün başarıyla silindi!");
        _fetchProducts();
        _refreshMovements(); // Logları yenile
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Silme başarısız: ${response.statusCode}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bağlantı hatası!")));
    }
  }

  void _showDeleteConfirmation(int id, String productName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ürünü Sil"),
        content: Text("'$productName' adlı ürünü kalıcı olarak silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _deleteProduct(id);
            },
            child: const Text("Sil", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog() {
    // ... Yeni ürün ekleme pop-up içeriği aynı kalıyor ...
    final nameCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    final kgCtrl = TextEditingController();
    final gramCtrl = TextEditingController();
    final shelfCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Yeni Ürün Ekle"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Ürün Adı")),
              TextField(controller: stockCtrl, decoration: const InputDecoration(labelText: "Stok Miktarı"), keyboardType: TextInputType.number),
              Row(
                children: [
                  Expanded(child: TextField(controller: kgCtrl, decoration: const InputDecoration(labelText: "Kilogram (kg)"), keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: gramCtrl, decoration: const InputDecoration(labelText: "Gram (gr)"), keyboardType: TextInputType.number)),
                ],
              ),
              TextField(controller: shelfCtrl, decoration: const InputDecoration(labelText: "Raf ID (Örn: 1, 2, 3)"), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () async {
              if (nameCtrl.text.isEmpty || shelfCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen Ürün Adı ve Raf ID girin!")));
                return;
              }

              double unitWeight = (int.tryParse(kgCtrl.text) ?? 0) + ((int.tryParse(gramCtrl.text) ?? 0) / 1000.0);
              int stock = int.tryParse(stockCtrl.text) ?? 0;
              double addedWeight = unitWeight * stock;
              int targetShelfId = int.tryParse(shelfCtrl.text) ?? 0;

              String? targetShelfCode;
              for (var s in _shelves) {
                if (s['id'] == targetShelfId) {
                  targetShelfCode = s['shelfCode'];
                  break;
                }
              }

              double currentShelfWeight = 0.0;
              for (var p in _products) {
                if ((targetShelfCode != null && p['shelfCode'] == targetShelfCode) || p['shelfId'] == targetShelfId || (p['shelf'] != null && p['shelf']['id'] == targetShelfId)) {
                  currentShelfWeight += (p['stockQuantity'] ?? 0).toDouble() * (p['weight'] ?? 0.0).toDouble();
                }
              }

              if (currentShelfWeight + addedWeight > 320.0) {
                String errorMsg = "Raf kapasitesi (320 kg) aşılıyor!\nMevcut: ${currentShelfWeight.toStringAsFixed(1)} kg | İstenen: ${addedWeight.toStringAsFixed(1)} kg";
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red, duration: const Duration(seconds: 4)));
                _sendErrorToBackend(errorMsg);
                return;
              }

              SharedPreferences prefs = await SharedPreferences.getInstance();
              String? token = prefs.getString('token');

              final response = await http.post(
                Uri.parse('$baseUrl/api/v1/products'),
                headers: {"Content-Type": "application/json", if (token != null) "Authorization": "Bearer $token"},
                body: jsonEncode({"name": nameCtrl.text, "stockQuantity": stock, "weight": unitWeight, "shelfId": targetShelfId}),
              );

              if (response.statusCode == 201 || response.statusCode == 200) {
                Navigator.pop(context);
                _fetchProducts();
                _refreshMovements();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Kaydetme başarısız: ${response.statusCode}")));
              }
            },
            child: const Text("Kaydet", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // 2 Sekmemiz var
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        body: Column(
          children: [
            // Üst Başlık ve Yeni Ekle Butonu
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Stok Yönetimi", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: _showAddProductDialog,
                    icon: const Icon(Icons.add, color: Colors.white, size: 20),
                    label: const Text("Yeni Ürün Ekle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),

            // Sekme (Tab) Menüsü
            Container(
              color: Colors.white,
              child: TabBar(
                labelColor: primaryColor,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: primaryColor,
                indicatorWeight: 3,
                tabs: const [
                  Tab(icon: Icon(Icons.inventory_2), text: "Mevcut Stoklar"),
                  Tab(icon: Icon(Icons.history), text: "Hareket Geçmişi"),
                ],
              ),
            ),

            // Sekme İçerikleri
            Expanded(
              child: TabBarView(
                children: [
                  _buildProductsTab(),  // 1. Sekme (Mevcut liste)
                  _buildMovementsTab(), // 2. Sekme (Hareket geçmişi)
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 1. SEKME İÇERİĞİ: MEVCUT ÜRÜNLER ---
  Widget _buildProductsTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final prod = _products[index];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: primaryColor.withOpacity(0.1), child: Icon(Icons.inventory, color: primaryColor)),
            title: Text(prod['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("SKU: ${prod['sku']} | Raf: ${prod['shelfCode'] ?? '-'} | Stok: ${prod['stockQuantity']} | Ağırlık: ${prod['weight'] ?? 0} kg"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: () => _showIncreaseStockDialog(prod), tooltip: "Yeni Stok Gir"),
                IconButton(icon: const Icon(Icons.remove_circle, color: Colors.orange), onPressed: () => _decreaseStock(prod['id']), tooltip: "Stok Düşür"),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _showDeleteConfirmation(prod['id'], prod['name']), tooltip: "Ürünü Sil"),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- 2. SEKME İÇERİĞİ: HAREKET GEÇMİŞİ ---
  Widget _buildMovementsTab() {
    return FutureBuilder<List<StockMovementModel>>(
      future: _movementsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text("Hata: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text("Henüz stok hareketi bulunmuyor.", style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
              ],
            ),
          );
        }

        final movements = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: movements.length,
          itemBuilder: (context, index) {
            final movement = movements[index];
            final isOut = movement.type == 'OUT';
            final color = isOut ? Colors.red : Colors.green;
            final icon = isOut ? Icons.arrow_upward : Icons.arrow_downward;
            final sign = isOut ? "-" : "+";

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                          child: Icon(icon, color: color, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(movement.productName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text("Raf: ${movement.shelfCode} | SKU: ${movement.sku ?? '-'}", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            ],
                          ),
                        ),
                        Text("$sign${movement.quantity}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDetailBadge(Icons.person, movement.workerName ?? "Sistem/Admin"),
                        _buildDetailBadge(Icons.assignment, movement.taskId != null ? "Görev #${movement.taskId}" : "Manuel İşlem"),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: _buildDetailBadge(Icons.info_outline, movement.reason ?? "Belirtilmedi", color: Colors.blueGrey)),
                        Text(DateFormat('dd.MM.yyyy HH:mm').format(movement.createdAt), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailBadge(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? Colors.grey.shade700),
        const SizedBox(width: 4),
        Flexible(child: Text(text, overflow: TextOverflow.ellipsis, style: TextStyle(color: color ?? Colors.grey.shade800, fontSize: 13))),
      ],
    );
  }
}