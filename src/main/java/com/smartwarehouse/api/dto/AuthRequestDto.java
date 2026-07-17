package com.smartwarehouse.api.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class AuthRequestDto {

    @NotBlank(message = "E-posta boş olamaz")
    private String email;

    @NotBlank(message = "Şifre boş olamaz")
    private String password;
}