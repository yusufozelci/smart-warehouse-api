class TaskModel {
  final int id;
  final String status;
  final String assignedWorkerName;
  final List<dynamic> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TaskModel({
    required this.id,
    required this.status,
    required this.assignedWorkerName,
    required this.items,
    this.createdAt,
    this.updatedAt,
  });
  TaskModel copyWith({
    String? status,
  }) {
    return TaskModel(
      id: id,
      status: status ?? this.status,
      assignedWorkerName: assignedWorkerName,
      items: items,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    List<dynamic> parsedItems = json['items'] ?? [];
    for (var item in parsedItems) {
      if (item['picked'] == true || item['isPicked'] == true) {
        item['isPicked'] = true;
      } else {
        item['isPicked'] = false;
      }
    }

    return TaskModel(
      id: json['id'],
      status: json['status'] ?? 'Bilinmiyor',
      assignedWorkerName: json['assignedWorkerName'] ?? 'Atanmamış',
      items: parsedItems,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }
}