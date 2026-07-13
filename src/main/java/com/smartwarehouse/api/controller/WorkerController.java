package com.smartwarehouse.api.controller;

import com.smartwarehouse.api.dto.WorkerRequestDto;
import com.smartwarehouse.api.dto.WorkerResponseDto;
import com.smartwarehouse.api.service.WorkerService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/workers")
@RequiredArgsConstructor
public class WorkerController {
    private final WorkerService workerService;


    @GetMapping
    public ResponseEntity<List<WorkerResponseDto>> getAllWorkers() {
        return ResponseEntity.ok(workerService.getAllWorkers());
    }

    @PostMapping
    public ResponseEntity<?> addWorker(@RequestBody WorkerRequestDto request) {
        return ResponseEntity.ok(workerService.registerWorker(request));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteWorker(@PathVariable Long id) {
        workerService.deleteWorker(id);
        return ResponseEntity.noContent().build();
    }

    @PutMapping("/{id}")
    public ResponseEntity<WorkerResponseDto> updateWorker(@PathVariable Long id, @RequestBody WorkerRequestDto request) {
        return ResponseEntity.ok(workerService.updateWorker(id, request));
    }
}
