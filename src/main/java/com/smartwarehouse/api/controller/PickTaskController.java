package com.smartwarehouse.api.controller;

import com.smartwarehouse.api.entity.PickTask;
import com.smartwarehouse.api.repository.PickTaskRepository;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/tasks")
public class PickTaskController {

    private final PickTaskRepository pickTaskRepository;

    public PickTaskController(PickTaskRepository pickTaskRepository) {
        this.pickTaskRepository = pickTaskRepository;
    }

    @PostMapping
    public ResponseEntity<PickTask> createTask(@RequestBody PickTask pickTask) {
        PickTask savedTask = pickTaskRepository.save(pickTask);
        return new ResponseEntity<>(savedTask, HttpStatus.CREATED);
    }

    @GetMapping
    public ResponseEntity<List<PickTask>> getAllTasks() {
        return ResponseEntity.ok(pickTaskRepository.findAll());
    }

    @PutMapping("/{id}/status")
    public ResponseEntity<PickTask> updateTaskStatus(@PathVariable Long id, @RequestParam com.smartwarehouse.api.entity.TaskStatus status) {
        return pickTaskRepository.findById(id).map(task -> {
            task.setStatus(status);
            return ResponseEntity.ok(pickTaskRepository.save(task));
        }).orElse(ResponseEntity.notFound().build());
    }
}