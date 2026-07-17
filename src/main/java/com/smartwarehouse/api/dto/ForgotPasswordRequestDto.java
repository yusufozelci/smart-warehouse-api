package com.smartwarehouse.api.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class ForgotPasswordRequestDto {

    @NotBlank(message = "İletişim bilgisi boş olamaz")
    @Email(message = "Lütfen geçerli bir e-posta adresi girin")
    private String contactInfo;

    @NotBlank(message = "Teslimat yöntemi boş olamaz")
    private String deliveryMethod;
}