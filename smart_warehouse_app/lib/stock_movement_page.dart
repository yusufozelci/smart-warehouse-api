import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_warehouse_app/services/stock_movement_service.dart';
import 'models/stock_movement_model.dart';

class StockMovementsPage extends StatefulWidget {
  const StockMovementsPage({super.key});

  @override
  State<StockMovementsPage> createState() => _StockMovementsPageState();
}

class _StockMovementsPageState extends State<StockMovementsPage> {
  late Future<List<StockMovementModel>> _movementsFuture;

  @override
  void initState() {
    super.initState();
    _refreshMovements();
  }

  void _refreshMovements() {
    setState(() {
      _movementsFuture = StockMovementService().getMovements();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Stok Hareket Geçmişi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A237E),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshMovements),
        ],
      ),
      body: FutureBuilder<List<StockMovementModel>>(
        future: _movementsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Hata: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          }
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
                          _buildDetailBadge(Icons.assignment, movement.taskId != null ? "Görev #${movement.taskId}" : "Manuel"),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: _buildDetailBadge(Icons.info_outline, movement.reason ?? "Belirtilmedi", color: Colors.blueGrey),
                          ),
                          Text(
                            DateFormat('dd.MM.yyyy HH:mm').format(movement.createdAt),
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailBadge(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? Colors.grey.shade700),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text, overflow: TextOverflow.ellipsis, style: TextStyle(color: color ?? Colors.grey.shade800, fontSize: 13)),
        ),
      ],
    );
  }
}