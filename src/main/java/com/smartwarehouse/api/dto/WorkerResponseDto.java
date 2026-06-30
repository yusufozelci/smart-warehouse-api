package com.smartwarehouse.api.dto;

import lombok.Data;

@Data
public class WorkerResponseDto {
    private Long id;
    private String firstName;
    private String lastName;
    private String role;

}