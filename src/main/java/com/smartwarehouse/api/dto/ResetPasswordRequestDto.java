package com.smartwarehouse.api.dto;
import lombok.Data;

@Data
public class ResetPasswordRequestDto {
    private String contactInfo;
    private String newPassword;
}