class DailyPerformanceModel {
  final String date;
  final int completedTaskCount;

  DailyPerformanceModel({required this.date, required this.completedTaskCount});

  factory DailyPerformanceModel.fromJson(Map<String, dynamic> json) {
    return DailyPerformanceModel(
      date: json['date'] ?? '',
      completedTaskCount: json['completedTaskCount'] ?? 0,
    );
  }
}

class WorkerPerformanceModel {
  final int workerId;
  final String workerFullName;
  final int totalTasksAssigned;
  final int completedTasks;
  final int cancelledTasks;
  final double successRate;
  final int totalCollectedItems;
  final int averageTaskDurationMinutes;
  final List<DailyPerformanceModel> weeklyGraphData;
  final List<DailyPerformanceModel> monthlyGraphData;

  WorkerPerformanceModel({
    required this.workerId,
    required this.workerFullName,
    required this.totalTasksAssigned,
    required this.completedTasks,
    required this.cancelledTasks,
    required this.successRate,
    required this.totalCollectedItems,
    required this.averageTaskDurationMinutes,
    required this.weeklyGraphData,
    required this.monthlyGraphData,
  });

  factory WorkerPerformanceModel.fromJson(Map<String, dynamic> json) {
    var weeklyList = (json['weeklyGraphData'] as List?) ?? [];
    var monthlyList = (json['monthlyGraphData'] as List?) ?? [];

    return WorkerPerformanceModel(
      workerId: json['workerId'] ?? 0,
      workerFullName: json['workerFullName'] ?? 'Bilinmiyor',
      totalTasksAssigned: json['totalTasksAssigned'] ?? 0,
      completedTasks: json['completedTasks'] ?? 0,
      cancelledTasks: json['cancelledTasks'] ?? 0,
      successRate: (json['successRate'] ?? 0).toDouble(),
      totalCollectedItems: json['totalCollectedItems'] ?? 0,
      averageTaskDurationMinutes: json['averageTaskDurationMinutes'] ?? 0,
      weeklyGraphData: weeklyList.map((e) => DailyPerformanceModel.fromJson(e)).toList(),
      monthlyGraphData: monthlyList.map((e) => DailyPerformanceModel.fromJson(e)).toList(),
    );
  }
}