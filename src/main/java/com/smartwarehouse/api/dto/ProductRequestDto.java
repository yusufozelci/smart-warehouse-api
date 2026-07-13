package com.smartwarehouse.api.dto;

import lombok.Data;

@Data
public class ProductRequestDto {

    private String name;
    private String sku;
    private int stockQuantity;
    private Long shelfId;
    private Double weight;

}