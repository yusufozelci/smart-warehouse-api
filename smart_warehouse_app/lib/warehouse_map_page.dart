import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WarehouseMapPage extends StatefulWidget {
  const WarehouseMapPage({super.key});

  @override
  State<WarehouseMapPage> createState() => _WarehouseMapPageState();
}

class _WarehouseMapPageState extends State<WarehouseMapPage> with TickerProviderStateMixin {
  List<dynamic> _shelves = [];
  List<dynamic> _allProducts = [];
  bool _isLoading = true;
  int _selectedFloor = 1;
  bool _isInitialFitDone = false;
  Map<String, dynamic>? _selectedShelf;

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
    _fetchMapData();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animController?.dispose();
    super.dispose();
  }

  Future<void> _fetchMapData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final headers = {"Content-Type": "application/json", if (token != null) "Authorization": "Bearer $token"};

      final shelfRes = await http.get(Uri.parse('$baseUrl/api/v1/shelves'), headers: headers);
      final prodRes = await http.get(Uri.parse('$baseUrl/api/v1/products'), headers: headers);

      if (shelfRes.statusCode == 200 && prodRes.statusCode == 200) {
        setState(() {
          _shelves = jsonDecode(shelfRes.body);
          _allProducts = jsonDecode(prodRes.body);
          _isLoading = false;
        });

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

  void _showProductsDialog(List<dynamic> products, String shelfCode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.inventory_2, color: Color(0xFF6200EA)),
            const SizedBox(width: 10),
            Text("$shelfCode Products", style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: products.isEmpty
              ? const Padding(
            padding: EdgeInsets.all(20),
            child: Text("No products found in this shelf.", style: TextStyle(color: Colors.grey)),
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
                title: Text(p['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("SKU: ${p['sku'] ?? '-'}"),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("${p['stockQuantity']} Units", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    Text("${p['weight']} kg/unit", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close", style: TextStyle(color: Color(0xFF6200EA), fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentFloorShelves = _shelves.where((s) => (s['floor'] ?? 1) == _selectedFloor).toList();

    int totalShelves = currentFloorShelves.length;
    int occupiedShelves = currentFloorShelves.where((s) {
      return _allProducts.any((p) => p['shelfCode'] == s['shelfCode'] && (p['stockQuantity'] ?? 0) > 0);
    }).length;
    int emptyShelves = totalShelves - occupiedShelves;

    return Container(
      color: Colors.transparent,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
          builder: (context, constraints) {
            bool isMobile = constraints.maxWidth < 800;

            if (isMobile) {
              return _buildMobileLayout(constraints, currentFloorShelves, totalShelves, occupiedShelves, emptyShelves);
            } else {
              return _buildDesktopLayout(constraints, currentFloorShelves, totalShelves, occupiedShelves, emptyShelves);
            }
          }
      ),
    );
  }

  Widget _buildDesktopLayout(BoxConstraints constraints, List currentFloorShelves, int totalShelves, int occupiedShelves, int emptyShelves) {
    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 1,
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300, width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: _buildMapViewer(currentFloorShelves, isMobile: false),
                    ),
                    _buildBottomBar(totalShelves, occupiedShelves, emptyShelves, currentFloorShelves),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 1,
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300, width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.dashboard_customize_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text("Sağ Panel Alanı", style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_selectedShelf != null)
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
    );
  }

  Widget _buildMobileLayout(BoxConstraints constraints, List currentFloorShelves, int totalShelves, int occupiedShelves, int emptyShelves) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedFloor,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      items: [1, 2, 3].map((v) => DropdownMenuItem(value: v, child: Text("F$v", style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
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
                    height: 40,
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
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
                          style: const TextStyle(fontSize: 14),
                          textAlignVertical: TextAlignVertical.center,
                          decoration: const InputDecoration(
                            hintText: "Search Shelf...",
                            prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey),
                            border: InputBorder.none,
                            isCollapsed: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            color: Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMobileKpi("$totalShelves", "Shelves", Colors.black87),
                _buildMobileKpi("$occupiedShelves", "Occupied", Colors.deepPurple),
                _buildMobileKpi("$emptyShelves", "Empty", Colors.grey),
              ],
            ),
          ),

          Expanded(
            child: Stack(
              children: [
                _buildMapViewer(currentFloorShelves, isMobile: true),

                if (_selectedShelf != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _buildMobileShelfDetailsCard(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileKpi(String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text("📦", style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(_selectedShelf!['shelfCode'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                ],
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
              child: const Text("View Products", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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

                      ...currentFloorShelves.map((shelf) {
                        double leftPos = (shelf['coordinateX'] ?? 0).toDouble();
                        double topPos = (shelf['coordinateY'] ?? 0).toDouble();

                        List<dynamic> productsInShelf = _allProducts.where((p) => p['shelfCode'] == shelf['shelfCode']).toList();
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

                        return Positioned(
                          left: leftPos,
                          top: topPos,
                          child: EnterpriseShelfWidget(
                            shelf: shelf,
                            occupancy: occupancy,
                            isSelected: _selectedShelf?['shelfCode'] == shelf['shelfCode'],
                            onTap: () => _focusOnShelf(shelf['shelfCode']),
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
                      tooltip: "Fit to Screen",
                      icon: const Icon(Icons.crop_free, color: Colors.deepPurple),
                      onPressed: () => _fitToScreen(),
                    ),
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
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
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
                items: [1, 2, 3].map((v) => DropdownMenuItem(value: v, child: Text("Floor $v", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))).toList(),
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
                      hintText: "Search Shelf...",
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
                _buildSmallKpi("$totalShelves", "Shelves", Colors.black87, Icons.grid_view),
                const SizedBox(width: 8),
                _buildSmallKpi("$occupiedShelves", "Occupied", Colors.deepPurple, Icons.inventory_2),
                const SizedBox(width: 8),
                _buildSmallKpi("$emptyShelves", "Empty", Colors.grey, Icons.check_box_outline_blank),
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
                      Row(
                        children: [
                          Icon(Icons.drag_indicator, color: Colors.grey.shade500, size: 18),
                          const SizedBox(width: 8),
                          const Text("Shelf Details", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ],
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
                      _buildPanelRow("Occupancy", "$occupancy%"),
                      _buildPanelRow("Total Items", "$productsCount Types"),
                      _buildPanelRow("Max Capacity", "${maxCapacity.toInt()} kg"),
                      _buildPanelRow("Current Weight", "${totalWeight.toStringAsFixed(1)} kg"),
                      _buildPanelRow("Temperature", "21°C"),
                      _buildPanelRow("Humidity", "58%"),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6200EA), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          onPressed: widget.onViewProducts,
                          child: const Text("View Products", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
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
  final VoidCallback onTap;

  const EnterpriseShelfWidget({super.key, required this.shelf, required this.occupancy, required this.isSelected, required this.onTap});

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

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered || widget.isSelected ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 140,
            height: 90,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isEmpty ? Colors.white : statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: widget.isSelected ? const Color(0xFF6200EA) : (isEmpty ? Colors.grey.shade300 : statusColor), width: widget.isSelected ? 3 : 2),
              boxShadow: [
                if (_isHovered || widget.isSelected) BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: isEmpty
                ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, color: Colors.grey, size: 28),
                const SizedBox(height: 5),
                Text(widget.shelf['shelfCode'].split('-').last, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              ],
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 4,
                  children: List.generate((widget.occupancy / 33).ceil(), (_) => const Text("📦", style: TextStyle(fontSize: 16))),
                ),
                Container(
                  height: 4,
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: widget.occupancy / 100,
                    child: Container(decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(2))),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.shelf['shelfCode'].split('-').last, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    Text("${widget.occupancy}%", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: statusColor)),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
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