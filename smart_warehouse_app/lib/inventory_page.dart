import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'global_utils.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  List<dynamic> _products = [];
  List<dynamic> _shelves = [];
  bool _isLoading = true;

  String get baseUrl => kIsWeb ? "http://localhost:8080" : (Platform.isAndroid ? "http://10.0.2.2:8080" : "http://localhost:8080");

  final Color primaryColor = const Color(0xFF1A237E);

  @override
  void initState() {
    super.initState();
    _fetchProducts();
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

  Future<void> _decreaseStock(int id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.put(
      Uri.parse('$baseUrl/api/v1/products/$id/decrease?amount=1'),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token"
      },
    );

    if (response.statusCode == 200) {
      _fetchProducts();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: ${response.statusCode} - ${response.body}")));
    }
  }

  Future<void> _deleteProduct(int id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/v1/products/$id'),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token"
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        showGlobalNotification("Ürün başarıyla silindi!");
        _fetchProducts();
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
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: "Ürün Adı")
              ),
              TextField(
                  controller: stockCtrl,
                  decoration: const InputDecoration(labelText: "Stok Miktarı"),
                  keyboardType: TextInputType.number
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                        controller: kgCtrl,
                        decoration: const InputDecoration(labelText: "Kilogram (kg)"),
                        keyboardType: TextInputType.number
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                        controller: gramCtrl,
                        decoration: const InputDecoration(labelText: "Gram (gr)"),
                        keyboardType: TextInputType.number
                    ),
                  ),
                ],
              ),
              TextField(
                  controller: shelfCtrl,
                  decoration: const InputDecoration(labelText: "Raf ID (Örn: 1, 2, 3)"),
                  keyboardType: TextInputType.number
              ),
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
                if ((targetShelfCode != null && p['shelfCode'] == targetShelfCode) ||
                    p['shelfId'] == targetShelfId ||
                    (p['shelf'] != null && p['shelf']['id'] == targetShelfId)) {
                  currentShelfWeight += (p['stockQuantity'] ?? 0).toDouble() * (p['weight'] ?? 0.0).toDouble();
                }
              }

              if (currentShelfWeight + addedWeight > 320.0) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          "Hata: Raf kapasitesi (320 kg) aşılıyor!\nMevcut: ${currentShelfWeight.toStringAsFixed(1)} kg | Eklenmek İstenen: ${addedWeight.toStringAsFixed(1)} kg"
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 4),
                    )
                );
                return;
              }

              SharedPreferences prefs = await SharedPreferences.getInstance();
              String? token = prefs.getString('token');

              final response = await http.post(
                Uri.parse('$baseUrl/api/v1/products'),
                headers: {
                  "Content-Type": "application/json",
                  if (token != null) "Authorization": "Bearer $token"
                },
                body: jsonEncode({
                  "name": nameCtrl.text,
                  "stockQuantity": stock,
                  "weight": unitWeight,
                  "shelfId": targetShelfId
                }),
              );

              if (response.statusCode == 201 || response.statusCode == 200) {
                Navigator.pop(context);
                _fetchProducts();
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
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Stok Yönetimi", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: Icon(Icons.add_box, color: primaryColor, size: 28), onPressed: _showAddProductDialog),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
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
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.orange),
                          onPressed: () => _decreaseStock(prod['id']),
                          tooltip: "Stok Düşür",
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _showDeleteConfirmation(prod['id'], prod['name']),
                          tooltip: "Ürünü Sil",
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}