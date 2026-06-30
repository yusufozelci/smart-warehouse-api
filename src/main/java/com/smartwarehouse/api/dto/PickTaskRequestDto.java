package com.smartwarehouse.api.dto;

import lombok.Data;

import java.util.List;

@Data
public class PickTaskRequestDto {
    private Long assignedWorkerId;
    private List<PickTaskItemRequestDto> items;

}