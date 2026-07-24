package com.smartwarehouse.api.dto;

import lombok.Data;
import java.util.List;

@Data
public class WorkerPerformanceDto {
    private Long workerId;
    private String workerFullName;
    private long totalTasksAssigned;
    private long completedTasks;
    private long cancelledTasks;
    private double successRate;
    private long totalCollectedItems;
    private long averageTaskDurationMinutes;

    private List<DailyPerformanceDto> weeklyGraphData;
    private List<DailyPerformanceDto> monthlyGraphData;
}