import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'global_utils.dart';

class ProductCatalogPage extends StatefulWidget {
  const ProductCatalogPage({super.key});

  @override
  State<ProductCatalogPage> createState() => _ProductCatalogPageState();
}

class _ProductCatalogPageState extends State<ProductCatalogPage> {
  List<dynamic> _products = [];
  bool _isLoading = true;
  final Color primaryColor = const Color(0xFF1A237E);

  String get baseUrl {
    if (kIsWeb) return "http://localhost:8080";
    if (Platform.isAndroid) return "http://10.0.2.2:8080";
    return "http://localhost:8080";
  }

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/products'),
        headers: {"Content-Type": "application/json", if (token != null) "Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        setState(() {
          _products = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        showGlobalNotification("Hata: Veriler çekilemedi.");
        setState(() => _isLoading = false);
      }
    } catch (e) {
      showGlobalNotification("Bağlantı hatası: $e");
      setState(() => _isLoading = false);
    }
  }

  void _showEditDialog(Map<String, dynamic> product) {
    final nameCtrl = TextEditingController(text: product['name']);
    final shelfCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                title: const Text("Ürün Bilgilerini Güncelle", style: TextStyle(fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("SKU: ${product['sku']}", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Ürün Adı", prefixIcon: Icon(Icons.edit))),
                    const SizedBox(height: 10),
                    TextField(
                      controller: shelfCtrl,
                      decoration: const InputDecoration(labelText: "Yeni Raf ID (Değişmeyecekse boş bırakın)", prefixIcon: Icon(Icons.shelves)),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: isSubmitting ? null : () => Navigator.pop(context), child: const Text("İptal")),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                    onPressed: isSubmitting ? null : () async {
                      setDialogState(() => isSubmitting = true);
                      try {
                        SharedPreferences prefs = await SharedPreferences.getInstance();
                        String? token = prefs.getString('token');

                        final bodyData = {"name": nameCtrl.text};
                        if (shelfCtrl.text.isNotEmpty) {
                          bodyData["shelfId"] = shelfCtrl.text;
                        }

                        final response = await http.put(
                          Uri.parse('$baseUrl/api/v1/products/${product['id']}'),
                          headers: {
                            "Content-Type": "application/json",
                            if (token != null) "Authorization": "Bearer $token"
                          },
                          body: jsonEncode(bodyData),
                        );

                        if (response.statusCode == 200) {
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          showGlobalNotification("Ürün güncellendi!");
                          _fetchProducts();
                        } else {
                          showGlobalNotification("Hata: ${response.statusCode}");
                        }
                      } catch (e) {
                        showGlobalNotification("Bağlantı hatası!");
                      } finally {
                        setDialogState(() => isSubmitting = false);
                      }
                    },
                    child: isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Kaydet"),
                  ),
                ],
              );
            }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Ürün Kataloğu", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _products.isEmpty
          ? const Center(child: Text("Sistemde ürün bulunmuyor.", style: TextStyle(fontSize: 18, color: Colors.grey)))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final prod = _products[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.info_outline, color: Colors.blue),
              ),
              title: Text(prod['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text("SKU: ${prod['sku']} | Raf: ${prod['shelfCode'] ?? '-'}"),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                tooltip: "Bilgileri Düzenle",
                onPressed: () => _showEditDialog(prod),
              ),
            ),
          );
        },
      ),
    );
  }
}