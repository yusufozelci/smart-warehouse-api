package com.smartwarehouse.api.dto;

import lombok.Data;

@Data
public class ShelfRequestDto {
    private String shelfCode;
    private int coordinateX;
    private int coordinateY;
    private int floor;

}