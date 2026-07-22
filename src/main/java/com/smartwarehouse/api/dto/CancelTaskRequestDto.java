package com.smartwarehouse.api.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class CancelTaskRequestDto {

    @NotBlank(message = "İptal nedeni boş bırakılamaz")
    private String reason;
}