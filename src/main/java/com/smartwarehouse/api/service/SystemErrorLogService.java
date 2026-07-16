package com.smartwarehouse.api.service;

import com.smartwarehouse.api.dto.SystemErrorLogDto;
import com.smartwarehouse.api.entity.SystemErrorLog;
import com.smartwarehouse.api.repository.SystemErrorLogRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.transaction.annotation.Transactional;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class SystemErrorLogService {

    private final SystemErrorLogRepository errorLogRepository;
    private final org.springframework.messaging.simp.SimpMessagingTemplate messagingTemplate;

    public List<SystemErrorLogDto> getAllLogs() {
        return errorLogRepository.findAllByOrderByTimestampDesc().stream()
                .map(logEntity -> SystemErrorLogDto.builder()
                        .message(logEntity.getMessage())
                        .stackTrace(logEntity.getStackTrace())
                        .timestamp(logEntity.getTimestamp())
                        .build())
                .collect(Collectors.toList());
    }

    public long getLogCount() {
        return errorLogRepository.count();
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void saveErrorLog(String message, String stackTrace) {
        try {
            log.debug("Log servisine kayıt isteği ulaştı. Mesaj: {}", message);

            SystemErrorLog errorLog = new SystemErrorLog();
            errorLog.setTimestamp(LocalDateTime.now());
            errorLog.setMessage(message);
            errorLog.setStackTrace(stackTrace);

            errorLogRepository.save(errorLog);
            messagingTemplate.convertAndSend("/topic/admin/errors", "YENI_HATA");
            log.info("Sistem hata kaydı veritabanına başarıyla işlendi.");

        } catch (Exception e) {
            log.error("KRİTİK HATA! Sistem hata kaydı veritabanına yazılamadı!", e);
        }
    }
}