package com.smartwarehouse.api.dto;
import lombok.Data;

@Data
public class VerifyOtpRequestDto {
    private String contactInfo;
    private String otpCode;
}