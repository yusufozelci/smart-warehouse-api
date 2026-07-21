package com.smartwarehouse.api.controller;

import com.smartwarehouse.api.dto.StockMovementResponseDto;
import com.smartwarehouse.api.service.StockMovementService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/v1/stock-movements")
@RequiredArgsConstructor
public class StockMovementController {
    private final StockMovementService stockMovementService;

    @GetMapping
    public ResponseEntity<List<StockMovementResponseDto>> getMovements(@RequestParam(required = false) LocalDate from, @RequestParam(required = false) LocalDate to) {
        return ResponseEntity.ok(stockMovementService.getMovements(from, to));
    }
}
