package com.smartwarehouse.api.dto;

import lombok.Data;

@Data
public class AuthRequestDto {
    private String firstName;
    private String lastName;
    private String email;
    private String password;
    private String role;
}