package com.smartwarehouse.api.service;

import com.smartwarehouse.api.dto.DailyPerformanceDto;
import com.smartwarehouse.api.dto.WorkerPerformanceDto;
import com.smartwarehouse.api.entity.PickTask;
import com.smartwarehouse.api.entity.TaskStatus;
import com.smartwarehouse.api.entity.Worker;
import com.smartwarehouse.api.repository.PickTaskRepository;
import com.smartwarehouse.api.repository.WorkerRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class PerformanceService {

    private final PickTaskRepository pickTaskRepository;
    private final WorkerRepository workerRepository;

    @Transactional(readOnly = true)
    public WorkerPerformanceDto getWorkerPerformance(Long workerId) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new RuntimeException("Personel bulunamadı!"));

        WorkerPerformanceDto dto = new WorkerPerformanceDto();
        dto.setWorkerId(worker.getId());
        dto.setWorkerFullName(worker.getFirstName() + " " + worker.getLastName());
        long totalTasks = pickTaskRepository.countByAssignedWorkerIdAndIsDeletedFalse(workerId);
        long completedTasks = pickTaskRepository.countByAssignedWorkerIdAndStatusAndIsDeletedFalse(workerId, TaskStatus.COMPLETED);
        long cancelledTasks = pickTaskRepository.countByAssignedWorkerIdAndStatusAndIsDeletedFalse(workerId, TaskStatus.CANCELLED);
        long totalItems = pickTaskRepository.sumPickedItemsByWorkerId(workerId);

        dto.setTotalTasksAssigned(totalTasks);
        dto.setCompletedTasks(completedTasks);
        dto.setCancelledTasks(cancelledTasks);
        dto.setTotalCollectedItems(totalItems);
        double successRate = totalTasks == 0 ? 0 : ((double) completedTasks / totalTasks) * 100;
        dto.setSuccessRate(Math.round(successRate * 100.0) / 100.0);
        LocalDateTime thirtyDaysAgo = LocalDateTime.now().minusDays(30);
        List<PickTask> recentCompletedTasks = pickTaskRepository.findCompletedTasksSince(workerId, thirtyDaysAgo);
        long avgDuration = calculateAverageDuration(recentCompletedTasks);
        dto.setAverageTaskDurationMinutes(avgDuration);
        dto.setWeeklyGraphData(generateGraphData(recentCompletedTasks, 7));
        dto.setMonthlyGraphData(generateGraphData(recentCompletedTasks, 30));

        return dto;
    }

    private long calculateAverageDuration(List<PickTask> tasks) {
        if (tasks.isEmpty()) return 0;

        long totalMinutes = 0;
        for (PickTask task : tasks) {
            if (task.getCreatedAt() != null && task.getUpdatedAt() != null) {
                totalMinutes += Duration.between(task.getCreatedAt(), task.getUpdatedAt()).toMinutes();
            }
        }
        return totalMinutes / tasks.size();
    }

    private List<DailyPerformanceDto> generateGraphData(List<PickTask> tasks, int days) {
        LocalDate startDate = LocalDate.now().minusDays(days - 1);
        Map<LocalDate, Long> groupedByDate = tasks.stream()
                .filter(t -> !t.getUpdatedAt().toLocalDate().isBefore(startDate))
                .collect(Collectors.groupingBy(
                        t -> t.getUpdatedAt().toLocalDate(),
                        Collectors.counting()
                ));

        List<DailyPerformanceDto> graphData = new ArrayList<>();
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd");
        for (int i = 0; i < days; i++) {
            LocalDate currentDate = startDate.plusDays(i);
            long count = groupedByDate.getOrDefault(currentDate, 0L);
            graphData.add(new DailyPerformanceDto(currentDate.format(formatter), (int) count));
        }

        return graphData;
    }
}