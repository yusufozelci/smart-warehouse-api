package com.smartwarehouse.api.dto;

import com.smartwarehouse.api.entity.Role;
import lombok.Data;

@Data
public class WorkerRequestDto {
    private String firstName;
    private String lastName;
    private String email;
    private String password;
    private Role role;
}
