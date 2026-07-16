import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_warehouse_app/qr_scanner_page.dart';
import 'package:smart_warehouse_app/services/task_service.dart';
import 'package:smart_warehouse_app/global_utils.dart';
import '../models/task_model.dart';
import "services/route_services.dart";
import '../painters/route_painter.dart';

class WarehouseMapPage extends StatefulWidget {
  final bool isDashboard;
  final bool isWorkerMode;
  final TaskModel? workerTask;

  const WarehouseMapPage({
    super.key,
    this.isDashboard = false,
    this.isWorkerMode = false,
    this.workerTask
  });

  @override
  State<WarehouseMapPage> createState() => _WarehouseMapPageState();
}

class _WarehouseMapPageState extends State<WarehouseMapPage> with TickerProviderStateMixin {
  List<dynamic> _shelves = [];
  List<dynamic> _allProducts = [];
  List<dynamic> _workers = [];
  List<TaskModel> _tasks = [];
  bool _isLoading = true;
  int _selectedFloor = 1;
  bool _isInitialFitDone = false;
  Map<String, dynamic>? _selectedShelf;

  TaskModel? _focusedTask;

  final TransformationController _transformationController = TransformationController();
  AnimationController? _animController;
  Animation<Matrix4>? _animMap;
  final GlobalKey _mapAreaKey = GlobalKey();

  final double mapWidth = 1400;
  final double mapHeight = 1100;

  String get baseUrl => kIsWeb ? "http://localhost:8080" : (Platform.isAndroid ? "http://10.0.2.2:8080" : "http://localhost:8080");

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    if (widget.isWorkerMode && widget.workerTask != null) {
      _focusedTask = widget.workerTask;
    }

    _fetchAllData();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animController?.dispose();
    super.dispose();
  }

  void _sortTaskItems(TaskModel task) {
    if (_shelves.isEmpty) return;
    List<dynamic> items = List.from(task.items);

    for (var item in items) {
      var s = _shelves.firstWhere((sh) => sh['shelfCode'] == item['shelfCode'], orElse: () => null);
      item['_floor'] = s != null ? (s['floor'] ?? 1) : 1;
      item['_x'] = s != null ? (s['coordinateX'] ?? 0) : 0;
      item['_y'] = s != null ? (s['coordinateY'] ?? 0) : 0;
    }

    List<dynamic> sortedItems = [];
    var floors = items.map((i) => i['_floor']).toSet().toList()..sort();

    for (var floor in floors) {
      var floorItems = items.where((i) => i['_floor'] == floor).toList();
      double currentX = 80.0;
      double currentY = 480.0;

      while (floorItems.isNotEmpty) {
        floorItems.sort((a, b) {
          double distA = (a['_x'] - currentX).abs() + (a['_y'] - currentY).abs();
          double distB = (b['_x'] - currentX).abs() + (b['_y'] - currentY).abs();
          return distA.compareTo(distB);
        });

        var nearest = floorItems.removeAt(0);
        sortedItems.add(nearest);
        currentX = nearest['_x'].toDouble();
        currentY = nearest['_y'].toDouble();
      }
    }

    task.items.clear();
    task.items.addAll(sortedItems);
  }

  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final headers = {"Content-Type": "application/json", if (token != null) "Authorization": "Bearer $token"};

      final shelfRes = await http.get(Uri.parse('$baseUrl/api/v1/shelves'), headers: headers);
      final prodRes = await http.get(Uri.parse('$baseUrl/api/v1/products'), headers: headers);

      if (!widget.isWorkerMode) {
        final workerRes = await http.get(Uri.parse('$baseUrl/api/v1/workers'), headers: headers);
        final tasks = await TaskService().getAllTasks();
        if (workerRes.statusCode == 200) {
          _workers = jsonDecode(workerRes.body);
          tasks.sort((a, b) {
            int getStatusPriority(String status) {
              if (status == 'IN_PROGRESS') return 1;
              if (status == 'PENDING') return 2;
              return 3;
            }
            int pA = getStatusPriority(a.status);
            int pB = getStatusPriority(b.status);
            if (pA != pB) return pA.compareTo(pB);
            return b.id.compareTo(a.id);
          });

          _tasks = tasks;
        }
      }

      if (shelfRes.statusCode == 200 && prodRes.statusCode == 200) {
        setState(() {
          _shelves = jsonDecode(shelfRes.body);
          _allProducts = jsonDecode(prodRes.body);
          _isLoading = false;
        });

        if (_focusedTask != null) {
          var updatedTask = _tasks.where((t) => t.id == _focusedTask!.id).firstOrNull;
          if (updatedTask != null) {
            _focusedTask = updatedTask;
          }
          _sortTaskItems(_focusedTask!);

          if (widget.isWorkerMode) {
            var firstItem = _focusedTask!.items.firstWhere((i) => i['isPicked'] != true, orElse: () => _focusedTask!.items.first);
            var startShelf = _shelves.firstWhere((s) => s['shelfCode'] == firstItem['shelfCode'], orElse: () => null);
            if (startShelf != null) {
              _selectedFloor = startShelf['floor'] ?? 1;
            }
          }
        }

        if (!_isInitialFitDone) {
          _fitToScreen();
          _isInitialFitDone = true;
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Matrix4 _getFitMatrix() {
    final RenderBox? mapBox = _mapAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (mapBox == null) return Matrix4.identity();

    double scale = min(mapBox.size.width / mapWidth, mapBox.size.height / mapHeight) * 0.95;
    double dx = (mapBox.size.width - (mapWidth * scale)) / 2;
    double dy = (mapBox.size.height - (mapHeight * scale)) / 2;

    return Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale, scale, 1.0);
  }

  void _fitToScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _animateCamera(_getFitMatrix());
    });
  }

  void _zoom(double factor) {
    final Matrix4 current = _transformationController.value;
    final RenderBox? mapBox = _mapAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (mapBox == null) return;

    final double fitScale = min(mapBox.size.width / mapWidth, mapBox.size.height / mapHeight) * 0.95;
    final Offset center = Offset(mapBox.size.width / 2, mapBox.size.height / 2);

    final double currentScale = current.getMaxScaleOnAxis();
    double targetScale = currentScale * factor;

    if (targetScale <= fitScale) {
      _animateCamera(_getFitMatrix());
      return;
    }

    targetScale = targetScale.clamp(fitScale, 3.5);
    final double actualFactor = targetScale / currentScale;

    final Matrix4 target = Matrix4.identity()
      ..translate(center.dx * (1 - actualFactor), center.dy * (1 - actualFactor))
      ..scale(actualFactor)
      ..multiply(current);

    _animateCamera(target);
  }

  void _animateCamera(Matrix4 targetMatrix) {
    _animController?.stop();
    _animMap = Matrix4Tween(begin: _transformationController.value, end: targetMatrix).animate(
      CurvedAnimation(parent: _animController!, curve: Curves.easeInOutCubic),
    );
    _animMap!.addListener(() => _transformationController.value = _animMap!.value);
    _animController!.forward(from: 0);
  }

  void _focusOnShelf(String code) {
    if (widget.isDashboard || widget.isWorkerMode) return;

    final target = _shelves.firstWhere((s) => s['shelfCode'] == code && s['floor'] == _selectedFloor, orElse: () => null);
    if (target == null) return;

    setState(() {
      _selectedShelf = target;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final RenderBox? mapBox = _mapAreaKey.currentContext?.findRenderObject() as RenderBox?;
      if (mapBox == null) return;

      double targetX = (target['coordinateX'] ?? 0).toDouble();
      double targetY = (target['coordinateY'] ?? 0).toDouble();
      double centerX = targetX + 70;
      double centerY = targetY + 45;

      final targetMatrix = Matrix4.identity()
        ..translate(-centerX * 1.8 + (mapBox.size.width / 2), -centerY * 1.8 + (mapBox.size.height / 2))
        ..scale(1.8, 1.8, 1.0);

      _animateCamera(targetMatrix);
    });
  }

  void _focusOnTask(TaskModel task) {
    _sortTaskItems(task);
    setState(() {
      _focusedTask = task;
      _selectedShelf = null;
    });

    if (task.items.isNotEmpty) {
      String? targetShelfCode = task.items.first['shelfCode'];
      if (targetShelfCode != null) {
        var shelfData = _shelves.firstWhere((s) => s['shelfCode'] == targetShelfCode, orElse: () => null);
        if (shelfData != null) {
          setState(() {
            _selectedFloor = shelfData['floor'] ?? 1;
          });
        }
        _focusOnShelf(targetShelfCode);
      }
    }
  }

  RouteData _getRouteData() {
    if (_focusedTask == null || _focusedTask!.items.isEmpty) {
      return RouteData(points: [], segmentEnds: []);
    }
    return RouteService.calculateRoute(_shelves, _focusedTask!.items, _selectedFloor);
  }

  int _getCompletedRouteNodesCountForCurrentFloor() {
    if (_focusedTask == null) return 0;
    int count = 0;
    for (var item in _focusedTask!.items) {
      var shelf = _shelves.firstWhere((s) => s['shelfCode'] == item['shelfCode'], orElse: () => null);
      if (shelf != null && shelf['floor'] == _selectedFloor) {
        if (item['isPicked'] == true) count++;
      }
    }
    return count;
  }

  void _showProductsDialog(List<dynamic> products, String shelfCode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.inventory_2, color: Color(0xFF6200EA)),
            const SizedBox(width: 10),
            Expanded(child: Text("$shelfCode Ürünleri", style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: products.isEmpty
              ? const Padding(
            padding: EdgeInsets.all(20),
            child: Text("Bu rafta henüz ürün yok.", style: TextStyle(color: Colors.grey)),
          )
              : ListView.separated(
            shrinkWrap: true,
            itemCount: products.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final p = products[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF6200EA).withOpacity(0.1),
                  child: const Icon(Icons.inventory, color: Color(0xFF6200EA), size: 20),
                ),
                title: Text(p['name'] ?? 'Bilinmeyen Ürün', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("SKU: ${p['sku'] ?? '-'}"),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("${p['stockQuantity']} Adet", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    Text("${p['weight']} kg/adet", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Kapat", style: TextStyle(color: Color(0xFF6200EA), fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _showAssignWorkerDialog(TaskModel task) {
    int? selectedWorkerId;

    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setStateSB) {
                return AlertDialog(
                  title: Text("Görev ID: ${task.id} - Personel Ata", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Bu göreve manuel olarak personel atayabilirsiniz."),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: "Personel Seçin", border: OutlineInputBorder()),
                        value: selectedWorkerId,
                        items: _workers.where((w) => w['role'] == 'WORKER').map((w) {
                          return DropdownMenuItem<int>(
                            value: w['id'],
                            child: Text("${w['firstName']} ${w['lastName']}", overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) => setStateSB(() => selectedWorkerId = val),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6200EA)),
                      onPressed: selectedWorkerId == null ? null : () async {
                        bool success = await TaskService().assignTaskManually(task.id, selectedWorkerId!);
                        Navigator.pop(context);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Personel atandı!"), backgroundColor: Colors.green));
                          _fetchAllData();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Atama işlemi başarısız!"), backgroundColor: Colors.red));
                        }
                      },
                      child: const Text("Görevi Ata", style: TextStyle(color: Colors.white)),
                    )
                  ],
                );
              }
          );
        }
    );
  }

  void _showCreateTaskDialog() {
    int? selectedWorkerId;
    List<Map<String, dynamic>> taskItems = [];
    final qtyController = TextEditingController(text: "1");
    Map<String, dynamic>? selectedProduct;
    TextEditingController? prodSearchController;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setStateSB) {
              return AlertDialog(
                title: const Text("Yeni Görev Oluştur", style: TextStyle(fontWeight: FontWeight.bold)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                content: SizedBox(
                  width: 500,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: "Atanacak Personel (Opsiyonel)", border: OutlineInputBorder()),
                        value: selectedWorkerId,
                        items: [
                          const DropdownMenuItem(value: null, child: Text("Personel Atama (Bekleyen Havuza Düşer)")),
                          ..._workers.where((w) => w['role'] == 'WORKER').map((w) {
                            return DropdownMenuItem<int>(
                              value: w['id'],
                              child: Text("${w['firstName']} ${w['lastName']}", overflow: TextOverflow.ellipsis),
                            );
                          }).toList()
                        ],
                        onChanged: (val) => setStateSB(() => selectedWorkerId = val),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Autocomplete<Map<String, dynamic>>(
                                displayStringForOption: (option) => "${option['name']} (Stok: ${option['stockQuantity']})",
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) {
                                    return _allProducts.cast<Map<String, dynamic>>();
                                  }
                                  return _allProducts.where((p) =>
                                  p['name'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                                      (p['sku'] != null && p['sku'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase()))
                                  ).cast<Map<String, dynamic>>();
                                },
                                onSelected: (Map<String, dynamic> selection) {
                                  setStateSB(() => selectedProduct = selection);
                                },
                                fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                                  prodSearchController = textController;
                                  return TextField(
                                    controller: textController,
                                    focusNode: focusNode,
                                    decoration: InputDecoration(
                                      labelText: "Ürün Ara (İsim / SKU)",
                                      prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      isDense: true,
                                    ),
                                    onChanged: (val) {
                                      if(val.isEmpty) setStateSB(() => selectedProduct = null);
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: qtyController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: "Adet", border: OutlineInputBorder(), isDense: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: Color(0xFF6200EA), size: 40),
                              onPressed: () {
                                if (selectedProduct != null) {
                                  int qty = int.tryParse(qtyController.text) ?? 1;
                                  int currentStock = selectedProduct!['stockQuantity'] ?? 0;
                                  int alreadyInCart = taskItems.where((item) => item['productId'] == selectedProduct!['id'])
                                      .fold(0, (sum, item) => sum + (item['quantity'] as int));

                                  if (alreadyInCart + qty > currentStock) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text("Hata: Yetersiz Stok! (Mevcut Depo Stoğu: $currentStock)"),
                                        backgroundColor: Colors.red
                                    ));
                                    return;
                                  }

                                  setStateSB(() {
                                    taskItems.add({
                                      "productId": selectedProduct!['id'],
                                      "productName": selectedProduct!['name'],
                                      "quantity": qty,
                                      "shelfCode": selectedProduct!['shelfCode']
                                    });
                                    selectedProduct = null;
                                    qtyController.text = "1";
                                    prodSearchController?.clear();
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen listeden bir ürün seçin!")));
                                }
                              },
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (taskItems.isNotEmpty) ...[
                        const Align(alignment: Alignment.centerLeft, child: Text("Toplanacak Ürünler", style: TextStyle(fontWeight: FontWeight.bold))),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 150),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: taskItems.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              return ListTile(
                                dense: true,
                                title: Text(taskItems[index]['productName'], overflow: TextOverflow.ellipsis),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text("${taskItems[index]['quantity']} Adet", style: const TextStyle(fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                      onPressed: () => setStateSB(() => taskItems.removeAt(index)),
                                    )
                                  ],
                                ),
                              );
                            },
                          ),
                        )
                      ]
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("İptal"),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6200EA)),
                    onPressed: taskItems.isEmpty ? null : () async {
                      List<Map<String, dynamic>> payloadItems = taskItems.map((e) => {
                        "productId": e["productId"],
                        "quantity": e["quantity"]
                      }).toList();

                      bool success = await TaskService().createTask(selectedWorkerId, payloadItems);

                      Navigator.pop(context);

                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Görev başarıyla oluşturuldu!"), backgroundColor: Colors.green));
                        _fetchAllData();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Görev oluşturulamadı!"), backgroundColor: Colors.red));
                      }
                    },
                    child: const Text("Görevi Oluştur", style: TextStyle(color: Colors.white)),
                  ),
                ],
              );
            },
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
                builder: (context, constraints) {
                  bool isMobile = constraints.maxWidth < 800;

                  if (isMobile) {
                    if (_isLoading) return const Center(child: CircularProgressIndicator());
                    final currentFloorShelves = _shelves.where((s) => (s['floor'] ?? 1) == _selectedFloor).toList();
                    int totalShelves = currentFloorShelves.length;
                    int occupiedShelves = currentFloorShelves.where((s) {
                      return _allProducts.any((p) => p['shelfCode'] == s['shelfCode'] && (p['stockQuantity'] ?? 0) > 0);
                    }).length;
                    int emptyShelves = totalShelves - occupiedShelves;

                    if (widget.isWorkerMode) {
                      return Column(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Container(
                              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 2))),
                              child: _buildMapViewer(currentFloorShelves, isMobile: true),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: _buildWorkerActionPanel(),
                          ),
                        ],
                      );
                    }
                    return _buildMobileLayout(constraints, currentFloorShelves, totalShelves, occupiedShelves, emptyShelves);
                  }
                  else {
                    if (_isLoading && _shelves.isEmpty) return const Center(child: CircularProgressIndicator());
                    final currentFloorShelves = _shelves.where((s) => (s['floor'] ?? 1) == _selectedFloor).toList();
                    int totalShelves = currentFloorShelves.length;
                    int occupiedShelves = currentFloorShelves.where((s) {
                      return _allProducts.any((p) => p['shelfCode'] == s['shelfCode'] && (p['stockQuantity'] ?? 0) > 0);
                    }).length;
                    int emptyShelves = totalShelves - occupiedShelves;

                    return _buildDesktopLayout(constraints, currentFloorShelves, totalShelves, occupiedShelves, emptyShelves);
                  }
                }
            ),
            if (_isLoading && _shelves.isNotEmpty)
              Positioned.fill(
                  child: Container(
                    color: Colors.white.withOpacity(0.5),
                    child: const Center(child: CircularProgressIndicator(color: Color(0xFF6200EA))),
                  )
              ),
            if (Navigator.canPop(context))
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))
                      ]
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A237E), size: 20),
                    padding: const EdgeInsets.only(right: 2),
                    tooltip: "Geri Dön",
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),

          ],
        ),
      ),
    );
  }

  Widget _buildWorkerActionPanel() {
    if (_focusedTask == null) return const SizedBox.shrink();

    bool allDone = _focusedTask!.items.every((i) => i['isPicked'] == true);
    int currentIndex = _focusedTask!.items.indexWhere((i) => i['isPicked'] != true);

    if (allDone) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        color: Colors.white,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 70),
            const SizedBox(height: 15),
            const Text("Tüm Ürünler Toplandı!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  bool success = await TaskService().completeTask(_focusedTask!.id);
                  if (success) {
                    showGlobalNotification("Görev başarıyla tamamlandı!");
                    if (!mounted) return;
                    if (widget.isWorkerMode && Navigator.canPop(context)) {
                      Navigator.pop(context, true);
                    } else {
                      setState(() {
                        _focusedTask = null;
                        _selectedShelf = null;
                      });
                      _fetchAllData();
                    }
                  }
                },
                child: const Text("Görevi Sonlandır", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200))
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                    "Toplama Listesi",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.deepPurple.shade100)
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.deepPurple, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "${_getCompletedRouteNodesCountForCurrentFloor()} / ${_focusedTask!.items.where((i){
                          var s = _shelves.firstWhere((sh)=>sh['shelfCode']==i['shelfCode'], orElse:()=>null);
                          return s != null && s['floor'] == _selectedFloor;
                        }).length} Bu Katta",
                        style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _focusedTask!.items.length,
              itemBuilder: (context, index) {
                var item = _focusedTask!.items[index];
                bool isPicked = item['isPicked'] == true;
                bool isCurrent = index == currentIndex;

                return _buildWorkerTaskItem(item, isPicked, isCurrent, index + 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerTaskItem(Map<String, dynamic> item, bool isPicked, bool isCurrent, int orderNumber) {
    int requestedQty = item['quantity'] ?? 1;

    if (isCurrent) {
      return Card(
        elevation: 4,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF1A237E), width: 2)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(backgroundColor: const Color(0xFF1A237E), radius: 14, child: Text("$orderNumber", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item['productName'] ?? 'Ürün', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _buildWorkerInfoBadge("Hedef Raf", item['shelfCode'] ?? '-', Icons.shelves, Colors.deepPurple)),
                  const SizedBox(width: 4),
                  Expanded(child: _buildWorkerInfoBadge("İstenen", "$requestedQty Adet", Icons.shopping_basket, Colors.blue)),
                  const SizedBox(width: 4),
                  Expanded(child: _buildWorkerInfoBadge("SKU", item['sku'] ?? '-', Icons.qr_code, Colors.orange)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
                  label: const Text("Rafı ve Ürünü Tara", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => QrScannerPage(expectedSku: item['sku'])));

                    if (!mounted) return;

                    if (result == true) {
                      bool success = await TaskService().pickItem(_focusedTask!.id, item['productId']);
                      if (success) {
                        setState(() {
                          item['isPicked'] = true;
                        });

                        int nextIndex = _focusedTask!.items.indexWhere((i) => i['isPicked'] != true);

                        if (nextIndex != -1) {
                          var nextItem = _focusedTask!.items[nextIndex];
                          int nextFloor = nextItem['_floor'] ?? 1;

                          if (nextFloor != _selectedFloor) {
                            setState(() {
                              _selectedFloor = nextFloor;
                              _selectedShelf = null;
                            });
                            _fitToScreen();
                            showGlobalNotification("Kat değiştirildi: $nextFloor. Kata geçiniz!");
                          } else {
                            showGlobalNotification("Ürün okundu. Sıradaki hedefe ilerleyin!");
                          }
                        } else {
                          showGlobalNotification("Son ürün okundu! Görevi sonlandırabilirsiniz.");
                        }
                      } else {
                        showGlobalNotification("Ürün okutulurken bir hata oluştu!");
                      }
                    }
                    else if (result == false) {
                      // KESİN ÇÖZÜM: SnackBar yerine ekranın ortasında çıkan Dialog!
                      showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Row(
                                children: [
                                  Icon(Icons.cancel, color: Colors.red, size: 28),
                                  SizedBox(width: 8),
                                  Text("Yanlış Ürün!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              content: const Text(
                                "Yanlış barkod okuttunuz. Lütfen doğru ürünü bularak tekrar deneyin.",
                                style: TextStyle(fontSize: 16),
                              ),
                              actions: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: const EdgeInsets.symmetric(vertical: 12)
                                    ),
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Tamam", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            );
                          }
                      );
                    }
                  },
                ),
              )
            ],
          ),
        ),
      );
    }

    return Opacity(
      opacity: isPicked ? 0.6 : 0.9,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        color: isPicked ? Colors.green.shade50 : Colors.grey.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
        child: ListTile(
          dense: true,
          leading: CircleAvatar(
              backgroundColor: isPicked ? Colors.green : Colors.grey.shade400,
              radius: 14,
              child: isPicked
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text("$orderNumber", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
          ),
          title: Text(item['productName'] ?? 'Ürün', style: TextStyle(fontWeight: FontWeight.bold, decoration: isPicked ? TextDecoration.lineThrough : null)),
          subtitle: Text("Kat: ${item['_floor']} | Raf: ${item['shelfCode']} | Adet: $requestedQty"),
        ),
      ),
    );
  }

  Widget _buildWorkerInfoBadge(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 10, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BoxConstraints constraints, List currentFloorShelves, int totalShelves, int occupiedShelves, int emptyShelves) {
    if (widget.isDashboard) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 1, child: _buildMapContainer(currentFloorShelves, totalShelves, occupiedShelves, emptyShelves)),
          const SizedBox(width: 24),
          Expanded(flex: 1, child: _buildTaskPanel()),
        ],
      );
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 1, child: _buildTaskPanel()),
          const SizedBox(width: 24),
          Expanded(
              flex: 2,
              child: Stack(
                children: [
                  _buildMapContainer(currentFloorShelves, totalShelves, occupiedShelves, emptyShelves),
                  if (_selectedShelf != null && !widget.isDashboard)
                    DraggableShelfPanel(
                      key: ValueKey(_selectedShelf!['shelfCode']),
                      shelf: _selectedShelf!,
                      productsInShelf: _allProducts.where((p) => p['shelfCode'] == _selectedShelf!['shelfCode']).toList(),
                      constraints: constraints,
                      onClose: () {
                        setState(() => _selectedShelf = null);
                        _fitToScreen();
                      },
                      onViewProducts: () => _showProductsDialog(
                          _allProducts.where((p) => p['shelfCode'] == _selectedShelf!['shelfCode']).toList(),
                          _selectedShelf!['shelfCode']
                      ),
                    ),
                ],
              )
          ),
        ],
      );
    }
  }

  Widget _buildMapContainer(List currentFloorShelves, int totalShelves, int occupiedShelves, int emptyShelves) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        children: [
          Expanded(child: _buildMapViewer(currentFloorShelves, isMobile: false)),
          _buildBottomBar(totalShelves, occupiedShelves, emptyShelves, currentFloorShelves),
        ],
      ),
    );
  }

  Widget _buildTaskPanel() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200))
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(widget.isDashboard ? Icons.assignment : Icons.share_location, color: const Color(0xFF6200EA)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(widget.isDashboard ? "Mevcut Görevler" : "Görev Kontrol Merkezi", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF6200EA)),
                  tooltip: "Verileri Yenile",
                  onPressed: () {
                    _fetchAllData();
                    showGlobalNotification("Harita ve Görevler Güncellendi");
                  },
                ),
                const SizedBox(width: 8),

                if (!widget.isDashboard)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6200EA), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    icon: const Icon(Icons.add, color: Colors.white, size: 18),
                    label: const Text("Yeni Görev", style: TextStyle(color: Colors.white)),
                    onPressed: _showCreateTaskDialog,
                  )
              ],
            ),
          ),
          Expanded(
              child: _tasks.isEmpty
                  ? Center(child: Text("Sistemde henüz görev bulunmuyor.", style: TextStyle(color: Colors.grey.shade500)))
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _tasks.length,
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  bool isCompleted = task.status == 'COMPLETED';
                  bool isUnassigned = task.assignedWorkerName == 'Atanmamış' || task.assignedWorkerName.isEmpty;
                  bool isFocused = _focusedTask?.id == task.id;

                  if (widget.isDashboard) {
                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                            isCompleted ? Icons.check_circle : (isUnassigned ? Icons.person_off : Icons.pending_actions),
                            color: isCompleted ? Colors.green : (isUnassigned ? Colors.red : Colors.orange),
                            size: 20
                        ),
                        title: Text("Görev ID: #${task.id}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                        subtitle: Text(isUnassigned ? "Personel Bekliyor" : "Atanan: ${task.assignedWorkerName}", style: TextStyle(color: isUnassigned ? Colors.red : Colors.grey.shade600, fontSize: 12)),
                      ),
                    );
                  }

                  return Card(
                    elevation: isFocused ? 4 : 1,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isFocused ? const Color(0xFF6200EA) : Colors.transparent, width: 2)
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: isCompleted ? Colors.green.shade50 : (isUnassigned ? Colors.red.shade50 : Colors.orange.shade50),
                            shape: BoxShape.circle
                        ),
                        child: Icon(
                            isCompleted ? Icons.check_circle : (isUnassigned ? Icons.person_off : Icons.pending_actions),
                            color: isCompleted ? Colors.green : (isUnassigned ? Colors.red : Colors.orange),
                            size: 28
                        ),
                      ),
                      title: Text("Görev ID: #${task.id}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isFocused ? const Color(0xFF6200EA) : Colors.black87)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isUnassigned ? "Personel Bekliyor" : "Atanan: ${task.assignedWorkerName}", style: TextStyle(color: isUnassigned ? Colors.red : Colors.grey.shade700, fontWeight: isUnassigned ? FontWeight.bold : FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text("Toplam ${task.items.length} Kalem Ürün", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                          ],
                        ),
                      ),
                      trailing: isUnassigned
                          ? ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        onPressed: () => _showAssignWorkerDialog(task),
                        child: const Text("Ata", style: TextStyle(color: Colors.white)),
                      )
                          : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      onTap: () => _focusOnTask(task),
                    ),
                  );
                },
              )
          )
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BoxConstraints constraints, List currentFloorShelves, int totalShelves, int occupiedShelves, int emptyShelves) {
    return Column(
      children: [
        if (!widget.isDashboard)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6200EA), padding: const EdgeInsets.symmetric(vertical: 12)),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text("Yeni Görev Oluştur", style: TextStyle(color: Colors.white, fontSize: 16)),
                onPressed: _showCreateTaskDialog,
              ),
            ),
          ),

        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(child: _buildMapViewer(currentFloorShelves, isMobile: true)),
                    _buildBottomBar(totalShelves, occupiedShelves, emptyShelves, currentFloorShelves),
                  ],
                ),
                if (_selectedShelf != null && !widget.isDashboard)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _buildMobileShelfDetailsCard(),
                  ),
              ],
            ),
          ),
        ),

        if (!widget.isDashboard) ...[
          const SizedBox(height: 12),
          Expanded(
            flex: 1,
            child: _buildTaskPanel(),
          )
        ]
      ],
    );
  }

  Widget _buildMobileShelfDetailsCard() {
    List<dynamic> productsInShelf = _allProducts.where((p) => p['shelfCode'] == _selectedShelf!['shelfCode']).toList();
    double totalWeight = 0.0;
    for (var p in productsInShelf) {
      double qty = (p['stockQuantity'] ?? 0).toDouble();
      double unitWeight = (p['weight'] ?? 0.0).toDouble();
      totalWeight += (qty * unitWeight);
    }
    double maxCapacity = 320.0;
    int occupancy = ((totalWeight / maxCapacity) * 100).toInt();
    if (totalWeight > 0 && occupancy == 0) occupancy = 1;
    if (occupancy > 100) occupancy = 100;
    int productsCount = productsInShelf.where((p) => (p['stockQuantity'] ?? 0) > 0).length;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 5))]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text("📦", style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_selectedShelf!['shelfCode'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () {
                  setState(() => _selectedShelf = null);
                  _fitToScreen();
                },
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMobileStatCol("Occupancy", "$occupancy%", Colors.deepPurple),
              _buildMobileStatCol("Items", "$productsCount", Colors.black87),
              _buildMobileStatCol("Weight", "${totalWeight.toStringAsFixed(1)} kg", Colors.black87),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6200EA), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () => _showProductsDialog(productsInShelf, _selectedShelf!['shelfCode']),
              child: const Text("Ürünleri Gör", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMobileStatCol(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  Widget _buildMapViewer(List currentFloorShelves, {required bool isMobile}) {
    return Listener(
      onPointerSignal: (event) {
        if (!isMobile && event is PointerScrollEvent) {
          GestureBinding.instance.pointerSignalResolver.register(event, (PointerSignalEvent e) {
            final double scaleChange = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
            final RenderBox? mapBox = _mapAreaKey.currentContext?.findRenderObject() as RenderBox?;
            if (mapBox == null) return;
            final double fitScale = min(mapBox.size.width / mapWidth, mapBox.size.height / mapHeight) * 0.95;
            final Matrix4 current = _transformationController.value;
            final double currentScale = current.getMaxScaleOnAxis();
            double targetScale = currentScale * scaleChange;

            if (targetScale <= fitScale) {
              _transformationController.value = _getFitMatrix();
              return;
            }
            targetScale = targetScale.clamp(fitScale, 3.5);
            final double actualFactor = targetScale / currentScale;
            final Offset focalPoint = event.localPosition;

            final Matrix4 target = Matrix4.identity()
              ..translate(focalPoint.dx * (1 - actualFactor), focalPoint.dy * (1 - actualFactor))
              ..scale(actualFactor)
              ..multiply(current);

            _transformationController.value = target;
          });
        }
      },
      child: ClipRect(
        key: _mapAreaKey,
        child: Stack(
          children: [
            InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.01,
              maxScale: 4.0,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              panEnabled: true,
              scaleEnabled: true,
              onInteractionEnd: (ScaleEndDetails details) {
                final RenderBox? mapBox = _mapAreaKey.currentContext?.findRenderObject() as RenderBox?;
                if (mapBox == null) return;
                final double fitScale = min(mapBox.size.width / mapWidth, mapBox.size.height / mapHeight) * 0.95;
                final double currentScale = _transformationController.value.getMaxScaleOnAxis();
                if (currentScale < fitScale) {
                  _animateCamera(_getFitMatrix());
                }
              },
              child: GestureDetector(
                onDoubleTap: () => _zoom(1.5),
                child: SizedBox(
                  width: mapWidth,
                  height: mapHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(child: CustomPaint(painter: PremiumGridPainter())),

                      if (_focusedTask != null && _focusedTask!.items.isNotEmpty)
                        Positioned.fill(
                            child: Builder(
                                builder: (context) {
                                  var routeData = RouteService.calculateRoute(_shelves, _focusedTask!.items, _selectedFloor);
                                  int completedCount = _getCompletedRouteNodesCountForCurrentFloor();

                                  return CustomPaint(
                                    painter: RoutePainter(
                                      points: routeData.points,
                                      segmentEnds: routeData.segmentEnds,
                                      completedNodesCount: completedCount,
                                    ),
                                  );
                                }
                            )
                        ),

                      ...currentFloorShelves.map((shelf) {
                        double leftPos = (shelf['coordinateX'] ?? 0).toDouble();
                        double topPos = (shelf['coordinateY'] ?? 0).toDouble();
                        List<dynamic> productsInShelf = _allProducts.where((p) => p['shelfCode'] == shelf['shelfCode']).toList();
                        double totalWeight = 0.0;
                        for (var p in productsInShelf) {
                          totalWeight += ((p['stockQuantity'] ?? 0).toDouble() * (p['weight'] ?? 0.0).toDouble());
                        }

                        int occupancy = ((totalWeight / 320.0) * 100).toInt();
                        if (totalWeight > 0 && occupancy == 0) occupancy = 1;
                        if (occupancy > 100) occupancy = 100;
                        bool isTarget = false;
                        bool isCompletedTarget = false;

                        if (_focusedTask != null) {
                          isTarget = _focusedTask!.items.any((item) => item['shelfCode'] == shelf['shelfCode'] && item['isPicked'] != true);
                          if (!isTarget) {
                            isCompletedTarget = _focusedTask!.items.any((item) => item['shelfCode'] == shelf['shelfCode'] && item['isPicked'] == true);
                          }
                        }

                        return Positioned(
                          left: leftPos,
                          top: topPos,
                          child: EnterpriseShelfWidget(
                            shelf: shelf,
                            occupancy: occupancy,
                            isSelected: _selectedShelf?['shelfCode'] == shelf['shelfCode'],
                            isTarget: isTarget,
                            isCompletedTarget: isCompletedTarget,
                            onTap: widget.isDashboard || widget.isWorkerMode ? () {} : () => _focusOnShelf(shelf['shelfCode']),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: isMobile && _selectedShelf != null ? 220 : 20,
              right: 16,
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.add), onPressed: () => _zoom(1.2)),
                    const Divider(height: 1),
                    IconButton(icon: const Icon(Icons.remove), onPressed: () => _zoom(0.8)),
                    const Divider(height: 1),
                    IconButton(
                      tooltip: "Ekrana Sığdır",
                      icon: const Icon(Icons.crop_free, color: Colors.deepPurple),
                      onPressed: () => _fitToScreen(),
                    ),
                    if (isMobile) ...[
                      const Divider(height: 1),
                      PopupMenuButton<int>(
                        initialValue: _selectedFloor,
                        tooltip: "Kat Seç",
                        offset: const Offset(-50, -120),
                        icon: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.deepPurple.shade50,
                          child: Text("K$_selectedFloor", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                        ),
                        onSelected: (v) {
                          setState(() {
                            _selectedFloor = v;
                            _selectedShelf = null;
                          });
                          _fitToScreen();
                        },
                        itemBuilder: (context) => [1, 2, 3].map((v) => PopupMenuItem(value: v, child: Text("$v. Kat'a Geç"))).toList(),
                      ),
                    ]
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(int totalShelves, int occupiedShelves, int emptyShelves, List currentFloorShelves) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade300)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedFloor,
                icon: const Icon(Icons.arrow_drop_down, size: 20),
                items: [1, 2, 3].map((v) => DropdownMenuItem(value: v, child: Text("Kat $v", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedFloor = v;
                      _selectedShelf = null;
                    });
                    _fitToScreen();
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade300)),
              child: Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                  return currentFloorShelves.map((s) => s['shelfCode'] as String).where((code) => code.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                },
                onSelected: (String selection) => _focusOnShelf(selection),
                fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: textController,
                    focusNode: focusNode,
                    style: const TextStyle(fontSize: 13),
                    textAlignVertical: TextAlignVertical.center,
                    decoration: const InputDecoration(
                      hintText: "Rafta Ara...",
                      prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey),
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                _buildSmallKpi("$totalShelves", "Raflar", Colors.black87, Icons.grid_view),
                const SizedBox(width: 8),
                _buildSmallKpi("$occupiedShelves", "Dolu", Colors.deepPurple, Icons.inventory_2),
                const SizedBox(width: 8),
                _buildSmallKpi("$emptyShelves", "Boş", Colors.grey, Icons.check_box_outline_blank),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallKpi(String value, String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300)
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color.withOpacity(0.7)),
          const SizedBox(width: 6),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color, height: 1.0)),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade600, height: 1.0)),
            ],
          ),
        ],
      ),
    );
  }
}

class DraggableShelfPanel extends StatefulWidget {
  final Map<String, dynamic> shelf;
  final List<dynamic> productsInShelf;
  final BoxConstraints constraints;
  final VoidCallback onClose;
  final VoidCallback onViewProducts;

  const DraggableShelfPanel({
    super.key,
    required this.shelf,
    required this.productsInShelf,
    required this.constraints,
    required this.onClose,
    required this.onViewProducts,
  });

  @override
  State<DraggableShelfPanel> createState() => _DraggableShelfPanelState();
}

class _DraggableShelfPanelState extends State<DraggableShelfPanel> {
  double _x = 10.0;
  double _y = 50.0;
  final double panelWidth = 280.0;

  @override
  Widget build(BuildContext context) {
    double totalWeight = 0.0;
    for (var p in widget.productsInShelf) {
      double qty = (p['stockQuantity'] ?? 0).toDouble();
      double unitWeight = (p['weight'] ?? 0.0).toDouble();
      totalWeight += (qty * unitWeight);
    }

    double maxCapacity = 320.0;
    int occupancy = ((totalWeight / maxCapacity) * 100).toInt();
    if (totalWeight > 0 && occupancy == 0) occupancy = 1;
    if (occupancy > 100) occupancy = 100;
    int productsCount = widget.productsInShelf.where((p) => (p['stockQuantity'] ?? 0) > 0).length;

    return Positioned(
      left: _x,
      top: _y,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: panelWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    double newX = _x + details.delta.dx;
                    double newY = _y + details.delta.dy;

                    double maxX = widget.constraints.maxWidth - panelWidth;
                    double maxY = widget.constraints.maxHeight - 60.0;

                    if (maxX < 0) maxX = 0;
                    if (maxY < 0) maxY = 0;

                    _x = newX.clamp(0.0, maxX);
                    _y = newY.clamp(0.0, maxY);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.drag_indicator, color: Colors.grey.shade500, size: 18),
                            const SizedBox(width: 8),
                            const Expanded(child: Text("Raf Detayları", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87), overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),
                ),
              ),

              Container(
                constraints: const BoxConstraints(maxHeight: 400),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text("📦", style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 8),
                          Text(widget.shelf['shelfCode'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      _buildPanelRow("Doluluk", "$occupancy%"),
                      _buildPanelRow("Ürün Tipi", "$productsCount Çeşit"),
                      _buildPanelRow("Maks Kapasite", "${maxCapacity.toInt()} kg"),
                      _buildPanelRow("Mevcut Ağırlık", "${totalWeight.toStringAsFixed(1)} kg"),
                      _buildPanelRow("Sıcaklık", "21°C"),
                      _buildPanelRow("Nem", "58%"),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6200EA), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          onPressed: widget.onViewProducts,
                          child: const Text("Ürünleri Gör", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanelRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }
}

class EnterpriseShelfWidget extends StatefulWidget {
  final Map<String, dynamic> shelf;
  final int occupancy;
  final bool isSelected;
  final bool isTarget;
  final bool isCompletedTarget;
  final VoidCallback onTap;

  const EnterpriseShelfWidget({
    super.key,
    required this.shelf,
    required this.occupancy,
    required this.isSelected,
    this.isTarget = false,
    this.isCompletedTarget = false,
    required this.onTap
  });

  @override
  State<EnterpriseShelfWidget> createState() => _EnterpriseShelfWidgetState();
}

class _EnterpriseShelfWidgetState extends State<EnterpriseShelfWidget> {
  bool _isHovered = false;

  Color getOccupancyColor(int percent) {
    if (percent == 0) return Colors.white;
    if (percent <= 25) return const Color(0xFF4CAF50);
    if (percent <= 50) return const Color(0xFFFFEB3B);
    if (percent <= 75) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  @override
  Widget build(BuildContext context) {
    bool isEmpty = widget.occupancy == 0;
    Color statusColor = getOccupancyColor(widget.occupancy);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedScale(
              scale: _isHovered || widget.isSelected || widget.isTarget ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 140,
                height: 95,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isEmpty ? Colors.white : statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: widget.isTarget
                          ? Colors.redAccent
                          : (widget.isCompletedTarget
                          ? Colors.redAccent.withOpacity(0.3)
                          : (widget.isSelected ? const Color(0xFF6200EA) : (isEmpty ? Colors.grey.shade300 : statusColor))),
                      width: widget.isTarget || widget.isSelected || widget.isCompletedTarget ? 3 : 2
                  ),
                  boxShadow: [
                    if (_isHovered || widget.isSelected || widget.isTarget)
                      BoxShadow(color: widget.isTarget ? Colors.redAccent.withOpacity(0.3) : Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: isEmpty
                    ? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add, color: Colors.grey, size: 24),
                      const SizedBox(height: 4),
                      Text(
                        widget.shelf['shelfCode'].split('-').last,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                    ],
                  ),
                )
                    : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 2,
                        children: List.generate(
                          (widget.occupancy / 33).ceil(),
                              (_) => const Text("📦", style: TextStyle(fontSize: 14)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 4,
                        width: 110,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: widget.occupancy / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.shelf['shelfCode'].split('-').last,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "${widget.occupancy}%",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.isTarget || widget.isCompletedTarget)
          Positioned(
            top: -10,
            right: -10,
            child: CircleAvatar(
              radius: 14,
              backgroundColor: widget.isTarget ? Colors.redAccent : Colors.grey.shade400,
              child: Icon(
                  widget.isCompletedTarget ? Icons.check : Icons.location_on,
                  size: 18,
                  color: Colors.white
              ),
            ),
          )
      ],
    );
  }
}

class PremiumGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = Colors.grey.shade300..strokeWidth = 2.0..strokeCap = StrokeCap.round;
    for (double i = 0; i < size.width; i += 40) {
      for (double j = 0; j < size.height; j += 40) {
        canvas.drawPoints(ui.PointMode.points, [Offset(i, j)], dotPaint);
      }
    }

    _drawAisleLine(canvas, "AISLE A", const Offset(590, 80), const Offset(590, 400));
    _drawAisleLine(canvas, "AISLE B", const Offset(590, 600), const Offset(590, 1000));
    _drawAisleLine(canvas, "MAIN CROSSWAY", const Offset(80, 480), const Offset(1200, 480), isHorizontal: true);

    _drawZoneHeader(canvas, "🚚 RECEIVING DOCK", const Offset(100, 40), Colors.teal);
    _drawZoneHeader(canvas, "📦 PACKING AREA", Offset(size.width - 400, 40), Colors.blueAccent);
    _drawZoneHeader(canvas, "🚛 SHIPPING ZONE", Offset(size.width - 400, size.height - 50), Colors.deepOrange);
  }

  void _drawAisleLine(Canvas canvas, String text, Offset start, Offset end, {bool isHorizontal = false}) {
    final linePaint = Paint()..color = const Color(0xFFDBE7F2)..strokeWidth = 10.0..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, linePaint);

    final tp = TextPainter(
      text: TextSpan(text: "$text\n←────────────→", style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 4, height: 1.5)),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout();

    if (isHorizontal) {
      tp.paint(canvas, Offset(start.dx + 400, start.dy - 50));
    } else {
      tp.paint(canvas, Offset(start.dx - 100, start.dy + 120));
    }
  }

  void _drawZoneHeader(Canvas canvas, String title, Offset offset, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: title, style: TextStyle(color: color.withOpacity(0.6), fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}