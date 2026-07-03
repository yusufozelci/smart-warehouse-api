package com.smartwarehouse.api.controller;

import com.smartwarehouse.api.dto.PickTaskRequestDto;
import com.smartwarehouse.api.dto.PickTaskResponseDto;
import com.smartwarehouse.api.entity.PickTask;
import com.smartwarehouse.api.entity.TaskStatus;
import com.smartwarehouse.api.repository.PickTaskRepository;
import com.smartwarehouse.api.service.PickTaskService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/tasks")
public class PickTaskController {

    private final PickTaskService pickTaskService;
    private final PickTaskRepository pickTaskRepository;

    public PickTaskController(PickTaskService pickTaskService, PickTaskRepository pickTaskRepository) {
        this.pickTaskService = pickTaskService;
        this.pickTaskRepository = pickTaskRepository;
    }

    @PostMapping
    public ResponseEntity<PickTaskResponseDto> createTask(@RequestBody PickTaskRequestDto requestDto) {
        PickTaskResponseDto createdTask = pickTaskService.createPickTask(requestDto);
        return new ResponseEntity<>(createdTask, HttpStatus.CREATED);
    }

    @GetMapping
    public ResponseEntity<List<PickTask>> getAllTasks() {
        return ResponseEntity.ok(pickTaskRepository.findAll());
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
}