class TaskModel {
  final int id;
  final String status;
  final String assignedWorkerName;
  final List<dynamic> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? cancelReason;
  final String? cancelledBy;
  final String? completionDuration;

  TaskModel({
    required this.id,
    required this.status,
    required this.assignedWorkerName,
    required this.items,
    this.createdAt,
    this.updatedAt,
    this.cancelReason,
    this.cancelledBy,
    this.completionDuration,
  });

  TaskModel copyWith({
    String? status,
    String? cancelReason,
    String? cancelledBy,
  }) {
    return TaskModel(
      id: id,
      status: status ?? this.status,
      assignedWorkerName: assignedWorkerName,
      items: items,
      createdAt: createdAt,
      updatedAt: updatedAt,
      cancelReason: cancelReason ?? this.cancelReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
    );
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    List<dynamic> parsedItems = json['items'] ?? [];
    for (var item in parsedItems) {
      item['isPicked'] = (item['picked'] == true || item['isPicked'] == true);
    }

    String parsedStatus = json['status'] ?? 'Bilinmiyor';
    if (parsedStatus == 'DELETED') {
      parsedStatus = 'CANCELLED';
    }

    return TaskModel(
      id: json['id'],
      status: parsedStatus,
      assignedWorkerName: json['assignedWorkerName'] ?? 'Atanmamış',
      items: parsedItems,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      cancelReason: json['cancelReason'],
      cancelledBy: json['cancelledBy'],
      completionDuration: json['completionDuration']
    );
  }
}