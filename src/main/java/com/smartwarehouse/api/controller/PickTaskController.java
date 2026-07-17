package com.smartwarehouse.api.controller;

import com.smartwarehouse.api.dto.PickTaskRequestDto;
import com.smartwarehouse.api.dto.PickTaskResponseDto;
import com.smartwarehouse.api.dto.PickTaskItemRequestDto;
import com.smartwarehouse.api.entity.PickTask;
import com.smartwarehouse.api.entity.TaskStatus;
import com.smartwarehouse.api.entity.Worker;
import com.smartwarehouse.api.mapper.PickTaskMapper;
import com.smartwarehouse.api.repository.PickTaskRepository;
import com.smartwarehouse.api.repository.WorkerRepository;
import com.smartwarehouse.api.service.PickTaskService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/tasks")
public class    PickTaskController {

    private final PickTaskService pickTaskService;
    private final PickTaskRepository pickTaskRepository;
    private final PickTaskMapper pickTaskMapper;
    private final WorkerRepository workerRepository;
    private final SimpMessagingTemplate messagingTemplate;

    @PostMapping
    public ResponseEntity<PickTaskResponseDto> createTask(@RequestBody PickTaskRequestDto requestDto) {
        PickTaskResponseDto createdTask = pickTaskService.createPickTask(requestDto);
        return new ResponseEntity<>(createdTask, HttpStatus.CREATED);
    }

    @GetMapping
    public ResponseEntity<List<PickTaskResponseDto>> getAllTasks() {
        List<PickTaskResponseDto> dtoList = pickTaskService.findAllTasks()
                .stream()
                .map(pickTaskMapper::toResponseDto)
                .collect(Collectors.toList());
        return ResponseEntity.ok(dtoList);
    }

    @GetMapping("/worker/{workerId}")
    public ResponseEntity<List<PickTaskResponseDto>> getTasksByWorker(@PathVariable Long workerId) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new RuntimeException("Personel bulunamadı!"));
        List<PickTask> tasks = pickTaskService.getPendingTasksForWorker(worker);
        List<PickTaskResponseDto> response = tasks.stream()
                .map(pickTaskMapper::toResponseDto)
                .collect(Collectors.toList());

        return ResponseEntity.ok(response);
    }

    @PutMapping("/{id}/status")
    public ResponseEntity<PickTask> updateTaskStatus(@PathVariable Long id, @RequestParam TaskStatus status) {
        return pickTaskRepository.findById(id).map(task -> {
            task.setStatus(status);
            return ResponseEntity.ok(pickTaskRepository.save(task));
        }).orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/assign-closest")
    public ResponseEntity<PickTaskResponseDto> assignClosestTask(
            @RequestParam Long workerId,
            @RequestParam Long currentShelfId) {

        PickTaskResponseDto assignedTask = pickTaskService.assignClosestTaskToWorker(workerId, currentShelfId);
        return ResponseEntity.ok(assignedTask);
    }

    @PutMapping("/{id}/complete")
    public ResponseEntity<PickTaskResponseDto> completeTask(@PathVariable Long id) {
        PickTaskResponseDto completedTask = pickTaskService.completePickTask(id);
        return ResponseEntity.ok(completedTask);
    }

    @GetMapping("/worker/{workerId}/completed")
    public ResponseEntity<List<PickTaskResponseDto>> getCompletedTasksByWorker(@PathVariable Long workerId) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new RuntimeException("Personel bulunamadı!"));
        List<PickTask> tasks = pickTaskService.getCompletedTasksForWorker(worker);
        List<PickTaskResponseDto> response = tasks.stream()
                .map(pickTaskMapper::toResponseDto)
                .collect(Collectors.toList());

        return ResponseEntity.ok(response);
    }

    @PostMapping("/{taskId}/pick/{productId}")
    public ResponseEntity<PickTaskResponseDto> pickItem(
            @PathVariable Long taskId,
            @PathVariable Long productId) {
        PickTaskResponseDto updatedTask = pickTaskService.pickTaskItem(taskId, productId);
        return ResponseEntity.ok(updatedTask);
    }

    @PutMapping("/{taskId}/assign/{workerId}")
    public ResponseEntity<PickTaskResponseDto> assignTaskManually(
            @PathVariable Long taskId,
            @PathVariable Long workerId) {
        PickTaskResponseDto assignedTask = pickTaskService.assignTaskManually(taskId, workerId);
        return ResponseEntity.ok(assignedTask);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteTask(@PathVariable Long id) {
        PickTask task = pickTaskRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Görev bulunamadı!"));

        if (task.getStatus() != TaskStatus.PENDING) {
            return ResponseEntity.badRequest().build();
        }

        task.setIsDeleted(true);
        pickTaskRepository.save(task);
        Map<String, Object> payload = new HashMap<>();
        payload.put("type", "TASK_DELETED");
        payload.put("message", "Bir görev silindi.");
        payload.put("taskId", id);
        messagingTemplate.convertAndSend("/topic/manager/tasks", payload);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{taskId}/items")
    public ResponseEntity<PickTaskResponseDto> addItemToTask(
            @PathVariable Long taskId,
            @RequestBody PickTaskItemRequestDto itemDto) {
        PickTaskResponseDto updatedTask = pickTaskService.addItemToTask(taskId, itemDto);

        return ResponseEntity.ok(updatedTask);
    }

    @GetMapping("/deleted")
    public ResponseEntity<List<PickTaskResponseDto>> getDeletedTasks() {
        return ResponseEntity.ok(pickTaskService.getDeletedTasks().stream().map(pickTaskMapper::toResponseDto).collect(Collectors.toList()));
    }

    @GetMapping("/worker/{workerId}/deleted")
    public ResponseEntity<List<PickTaskResponseDto>> getDeletedTasksByWorker(@PathVariable Long workerId) {
        Worker worker = workerRepository.findById(workerId).orElseThrow(() -> new RuntimeException("Personel bulunamadı!"));
        return ResponseEntity.ok(pickTaskService.getDeletedTasksForWorker(worker).stream().map(pickTaskMapper::toResponseDto).collect(Collectors.toList()));
    }
}