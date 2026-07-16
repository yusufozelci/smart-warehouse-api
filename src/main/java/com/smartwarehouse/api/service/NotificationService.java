package com.smartwarehouse.api.service;

import com.twilio.Twilio;
import com.twilio.rest.verify.v2.service.Verification;
import com.twilio.rest.verify.v2.service.VerificationCheck;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class NotificationService {

    private final JavaMailSender mailSender;

    @Value("${twilio.account-sid}")
    private String accountSid;

    @Value("${twilio.auth-token}")
    private String authToken;

    @Value("${twilio.verify.service-sid}")
    private String verificationServiceSid;

    @Value("${spring.mail.username}")
    private String fromEmail;

    @PostConstruct
    public void initTwilio() {
        Twilio.init(accountSid, authToken);
        log.info("Twilio Verify servisi başarıyla başlatıldı.");
    }

    public void sendEmail(String toEmail, String subject, String text) {
        try {
            SimpleMailMessage message = new SimpleMailMessage();
            message.setFrom(fromEmail);
            message.setTo(toEmail);
            message.setSubject(subject);
            message.setText(text);

            mailSender.send(message);
            log.info("Doğrulama E-postası başarıyla gönderildi: {}", toEmail);
        } catch (Exception e) {
            log.error("E-posta gönderim hatası: {}", e.getMessage());
            throw new RuntimeException("E-posta gönderilemedi.");
        }
    }

    public void sendVerificationSms(String toPhoneNumber) {
        try {
            String formattedNumber = formatToE164(toPhoneNumber);
            Verification verification = Verification.creator(
                    verificationServiceSid,
                    formattedNumber,
                    "sms"
            ).create();

            log.info("Doğrulama SMS'i gönderildi. SID: {}", verification.getSid());
        } catch (Exception e) {
            log.error("SMS gönderim hatası: {}", e.getMessage());
            throw new RuntimeException("SMS gönderilemedi: " + e.getMessage());
        }
    }

    public String formatToE164(String phone) {
        String clean = phone.replaceAll("\\s+", "").replaceAll("-", "");
        if (clean.startsWith("0")) {
            return "+90" + clean.substring(1);
        }
        if (clean.startsWith("+")) {
            return clean;
        }
        return "+90" + clean;
    }

    public boolean verifyCode(String phoneNumber, String code) {
        try {
            String formattedNumber = formatToE164(phoneNumber);
            VerificationCheck check = VerificationCheck.creator(verificationServiceSid)
                    .setTo(formattedNumber)
                    .setCode(code)
                    .create();

            log.info("Doğrulama durumu: {}", check.getStatus());
            return "approved".equals(check.getStatus());

        } catch (com.twilio.exception.ApiException e) {
            log.error("Twilio Doğrulama API Hatası: {} - Kod: {}", e.getMessage(), e.getCode());
            return false;
        } catch (Exception e) {
            log.error("Doğrulama aşamasında beklenmedik hata: {}", e.getMessage());
            return false;
        }
    }
}