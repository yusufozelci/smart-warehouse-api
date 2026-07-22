package com.smartwarehouse.api.dto;

import lombok.Data;

@Data
public class PickTaskItemResponseDto {
    private Long id;
    private String productName;
    private String sku;
    private Long productId;
    private int quantity;
    private String shelfCode;
    private boolean isPicked;
    private int stockQuantity;
    private java.time.LocalDateTime createdAt;
    private java.time.LocalDateTime updatedAt;

}