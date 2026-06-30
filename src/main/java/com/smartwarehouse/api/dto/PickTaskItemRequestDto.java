package com.smartwarehouse.api.dto;

import lombok.Data;

@Data
public class PickTaskItemRequestDto {
    private Long productId;
    private int quantity;

}