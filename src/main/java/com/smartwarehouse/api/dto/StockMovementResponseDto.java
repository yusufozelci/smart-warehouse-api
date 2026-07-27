package com.smartwarehouse.api.dto;

import lombok.Data;

import java.time.LocalDateTime;

@Data
public class StockMovementResponseDto {
    private Long id;
    private Long productId;
    private String productName;
    private String sku;
    private String shelfCode;
    private Integer quantity;
    private String type;
    private String reason;
    private LocalDateTime createdAt;
    private String workerName;
    private Long taskId;
}
