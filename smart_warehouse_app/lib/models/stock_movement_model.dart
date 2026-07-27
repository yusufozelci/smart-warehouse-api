class StockMovementModel {
  final int id;
  final int? productId;
  final String productName;
  final String? sku;
  final String shelfCode;
  final int quantity;
  final String type;
  final String? reason;
  final String? workerName;
  final int? taskId;
  final DateTime createdAt;

  StockMovementModel({
    required this.id,
    this.productId,
    required this.productName,
    this.sku,
    required this.shelfCode,
    required this.quantity,
    required this.type,
    this.reason,
    this.workerName,
    this.taskId,
    required this.createdAt,
  });

  factory StockMovementModel.fromJson(Map<String, dynamic> json) {
    return StockMovementModel(
      id: json['id'],
      productId: json['productId'],
      productName: json['productName'] ?? 'Bilinmeyen Ürün',
      sku: json['sku'],
      shelfCode: json['shelfCode'] ?? '-',
      quantity: json['quantity'] ?? 0,
      type: json['type'] ?? 'OUT',
      reason: json['reason'],
      workerName: json['workerName'],
      taskId: json['taskId'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}