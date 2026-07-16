package com.smartwarehouse.api.entity;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@Entity
@Table(name = "system_error_logs")
public class SystemErrorLog {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private LocalDateTime timestamp;

    @Column(length = 1000)
    private String message;

    @Column(columnDefinition = "TEXT")
    private String stackTrace;
}