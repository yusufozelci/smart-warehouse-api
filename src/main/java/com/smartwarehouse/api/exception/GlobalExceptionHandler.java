package com.smartwarehouse.api.exception;

import com.smartwarehouse.api.service.SystemErrorLogService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.dao.OptimisticLockingFailureException;

import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import java.util.stream.Collectors;

@Slf4j
@RestControllerAdvice
@RequiredArgsConstructor
public class GlobalExceptionHandler {

    private final SystemErrorLogService logService;

    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ResponseEntity<Map<String, String>> handleValidationExceptions(MethodArgumentNotValidException ex) {
        Map<String, String> errors = new HashMap<>();
        ex.getBindingResult().getAllErrors().forEach((error) -> {
            String fieldName = ((FieldError) error).getField();
            String errorMessage = error.getDefaultMessage();
            errors.put(fieldName, errorMessage);
        });
        log.warn("Validasyon Hatası: {}", errors);
        return new ResponseEntity<>(errors, HttpStatus.BAD_REQUEST);
    }

    @ExceptionHandler(InvalidQrCodeException.class)
    public ResponseEntity<String> handleInvalidQrCode(InvalidQrCodeException e) {
        log.warn("QR Kod Hatası: {}", e.getMessage());

        logService.saveErrorLog(
                "Geçersiz QR Kod: " + e.getMessage(),
                Arrays.toString(e.getStackTrace())
        );

        return new ResponseEntity<>(e.getMessage(), HttpStatus.BAD_REQUEST);
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<String> handleIllegalArgumentException(IllegalArgumentException e) {
        log.warn("Kullanıcı Hatası (400): {}", e.getMessage());

        logService.saveErrorLog(
                "İşlem Hatası (400): " + e.getMessage(),
                Arrays.toString(e.getStackTrace())
        );

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(e.getMessage());
    }

    @ExceptionHandler({IllegalStateException.class, OptimisticLockingFailureException.class})
    public ResponseEntity<String> handleConflict(Exception e) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(e.getMessage());
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<String> handleAccessDenied(AccessDeniedException e) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Bu işlem için yetkiniz yok.");
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<String> handleGeneralException(Exception e) {
        log.error("Sistem Hatası (500): {}", e.getMessage(), e);

        logService.saveErrorLog(
                "Sistem Hatası (500): " + (e.getMessage() != null ? e.getMessage() : "Bilinmeyen Hata"),
                Arrays.toString(e.getStackTrace())
        );

        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body("Beklenmeyen bir sistem hatası oluştu.");
    }
}
