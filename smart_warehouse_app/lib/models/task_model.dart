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
    );
  }
}