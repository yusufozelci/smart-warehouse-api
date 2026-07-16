package com.smartwarehouse.api.dto;

import lombok.Builder;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@Builder
public class SystemErrorLogDto {
    private String message;
    private String stackTrace;
    private LocalDateTime timestamp;
}