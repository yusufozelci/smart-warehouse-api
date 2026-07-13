package com.smartwarehouse.api.dto;

import lombok.Data;

@Data
public class ShelfResponseDto {
    private Long id;
    private String shelfCode;
    private int coordinateX;
    private int coordinateY;
    private int floor;

}