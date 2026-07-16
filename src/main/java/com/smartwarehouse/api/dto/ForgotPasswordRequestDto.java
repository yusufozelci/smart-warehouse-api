package com.smartwarehouse.api.dto;
import lombok.Data;

@Data
public class ForgotPasswordRequestDto {
    private String contactInfo;
    private String deliveryMethod;
}