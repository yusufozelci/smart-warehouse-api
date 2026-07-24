package com.smartwarehouse.api.controller;

import com.smartwarehouse.api.dto.WorkerPerformanceDto;
import com.smartwarehouse.api.service.PerformanceService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/performance")
@RequiredArgsConstructor
public class PerformanceController {

    private final PerformanceService performanceService;
    @GetMapping("/worker/{workerId}")
    public ResponseEntity<WorkerPerformanceDto> getWorkerPerformance(@PathVariable Long workerId) {
        return ResponseEntity.ok(performanceService.getWorkerPerformance(workerId));
    }
}