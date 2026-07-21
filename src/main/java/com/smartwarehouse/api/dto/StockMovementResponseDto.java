package com.smartwarehouse.api.dto;

import lombok.Data;

import java.time.LocalDateTime;

@Data
public class StockMovementResponseDto {
    private Long id;
    private Long productId;
    private String productName;
    private String shelfCode;
    private Integer quantity;
    private String type;
    private String reason;
    private LocalDateTime createdAt;
}
