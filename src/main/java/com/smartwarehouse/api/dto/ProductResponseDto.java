package com.smartwarehouse.api.dto;

import lombok.Data;

import java.time.LocalDateTime;

@Data
public class ProductResponseDto {

    private Long id;
    private String name;
    private String sku;
    private int stockQuantity;
    private String shelfCode;
    private LocalDateTime createdAt;


}