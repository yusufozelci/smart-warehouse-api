package com.smartwarehouse.api.controller;

import com.smartwarehouse.api.dto.SystemErrorLogDto;
import com.smartwarehouse.api.service.SystemErrorLogService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/admin/logs")
@RequiredArgsConstructor
public class AdminLogController {

    private final SystemErrorLogService logService;

    @GetMapping
    public List<SystemErrorLogDto> getErrorLogs() {
        return logService.getAllLogs();
    }

    @PostMapping
    public ResponseEntity<Void> logFrontendError(@RequestBody SystemErrorLogDto errorLog) {
        logService.saveErrorLog(
                "[Frontend Uyarı]: " + errorLog.getMessage(),
                errorLog.getStackTrace() != null ? errorLog.getStackTrace() : "Flutter İstemcisi"
        );
        return ResponseEntity.ok().build();
    }
}