class TaskModel {
  final int id;
  final String status;
  final String assignedWorkerName;
  final List<dynamic> items;

  TaskModel({
    required this.id,
    required this.status,
    required this.assignedWorkerName,
    required this.items,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'],
      status: json['status'] ?? 'Bilinmiyor',
      assignedWorkerName: json['assignedWorkerName'] ?? 'Atanmamış',
      items: json['items'] ?? [],
    );
  }
}