package com.smartwarehouse.api.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class DailyPerformanceDto {
    private String date;
    private int completedTaskCount;
}