package com.smartwarehouse.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class ResetPasswordRequestDto {

    @NotBlank(message = "İletişim bilgisi (e-posta/telefon) boş olamaz")
    private String contactInfo;

    @NotBlank(message = "Yeni şifre boş olamaz")
    @Size(min = 8, message = "Yeni şifre en az 8 karakter uzunluğunda olmalıdır")
    private String newPassword;
}