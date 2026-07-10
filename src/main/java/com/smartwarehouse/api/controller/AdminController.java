package com.smartwarehouse.api.controller;

import com.smartwarehouse.api.entity.TaskStatus;
import com.smartwarehouse.api.repository.ProductRepository;
import com.smartwarehouse.api.repository.PickTaskRepository;
import com.smartwarehouse.api.repository.WorkerRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/admin")
public class AdminController {

    private final WorkerRepository workerRepository;
    private final ProductRepository productRepository;
    private final PickTaskRepository pickTaskRepository;

    public AdminController(WorkerRepository workerRepository,
                           ProductRepository productRepository,
                           PickTaskRepository pickTaskRepository) {
        this.workerRepository = workerRepository;
        this.productRepository = productRepository;
        this.pickTaskRepository = pickTaskRepository;
    }

    @GetMapping("/stats")
    public ResponseEntity<Map<String, Long>> getDashboardStats() {
        Map<String, Long> stats = new HashMap<>();
        stats.put("activeWorkers", workerRepository.count());
        stats.put("totalProducts", productRepository.count());
        stats.put("completedTasks", pickTaskRepository.countByStatus(TaskStatus.COMPLETED));
        stats.put("errorLogs", 0L);

        return ResponseEntity.ok(stats);
    }
}