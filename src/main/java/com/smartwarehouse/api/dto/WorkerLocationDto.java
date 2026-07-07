package com.smartwarehouse.api.dto;

import lombok.Data;

@Data
public class WorkerLocationDto {
    private Long workerId;
    private String workerName;
    private Long currentShelfId;
    private String status;
}