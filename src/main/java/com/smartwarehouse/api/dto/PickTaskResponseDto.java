package com.smartwarehouse.api.dto;

import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

@Data
public class PickTaskResponseDto {
    private Long id;
    private String status;
    private String assignedWorkerName;
    private List<PickTaskItemResponseDto> items;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

}