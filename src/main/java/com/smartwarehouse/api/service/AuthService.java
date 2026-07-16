package com.smartwarehouse.api.service;

import com.smartwarehouse.api.entity.Worker;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.util.Random;
import java.util.concurrent.TimeUnit;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private final StringRedisTemplate redisTemplate;
    private final NotificationService notificationService;
    private final WorkerService workerService;

    private static final String OTP_PREFIX = "OTP_";
    private static final String PERMIT_PREFIX = "RESET_PERMIT_";
    private static final long OTP_VALIDITY_MINUTES = 3;

    public void generateAndSendOtp(String contactInfo, boolean isSms) {
        if (isSms) {
            notificationService.sendVerificationSms(contactInfo);
            log.info("Doğrulama SMS'i gönderildi (Verify API) -> {}", contactInfo);
        } else {
            String otp = String.format("%06d", new Random().nextInt(999999));
            redisTemplate.opsForValue().set(OTP_PREFIX + contactInfo, otp, OTP_VALIDITY_MINUTES, TimeUnit.MINUTES);

            String messageBody = "Smart Warehouse - Şifre Sıfırlama Kodunuz: " + otp + ". Kod 3 dakika geçerlidir.";
            notificationService.sendEmail(contactInfo, "Smart Warehouse - Şifre Sıfırlama", messageBody);
            log.info("OTP Üretildi (Email) -> {}", otp);
        }
    }

    public boolean verifyOtp(String contactInfo, String enteredOtp) {
        boolean isValid = false;
        String savedOtp = redisTemplate.opsForValue().get(OTP_PREFIX + contactInfo);

        if (savedOtp != null) {
            if (savedOtp.equals(enteredOtp)) {
                redisTemplate.delete(OTP_PREFIX + contactInfo);
                isValid = true;
            }
        } else {
            isValid = notificationService.verifyCode(contactInfo, enteredOtp);
        }

        if (isValid) {
            redisTemplate.opsForValue().set(PERMIT_PREFIX + contactInfo, "true", 5, TimeUnit.MINUTES);
            return true;
        }
        return false;
    }

    public boolean checkResetPermit(String contactInfo) {
        String permit = redisTemplate.opsForValue().get(PERMIT_PREFIX + contactInfo);
        return "true".equals(permit);
    }

    public void clearResetPermit(String contactInfo) {
        redisTemplate.delete(PERMIT_PREFIX + contactInfo);
    }
    public void resetPassword(String contactInfo, String newPassword) {
        if (!checkResetPermit(contactInfo)) {
            throw new RuntimeException("Şifre sıfırlama izniniz yok veya süresi dolmuş.");
        }
        String formattedNumber = notificationService.formatToE164(contactInfo);
        Worker worker = workerService.findWorkerByContact(contactInfo, formattedNumber);
        workerService.updatePassword(worker, newPassword);

        clearResetPermit(contactInfo);
        log.info("Şifre başarıyla güncellendi: {}", contactInfo);
    }
}