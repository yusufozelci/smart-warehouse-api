package com.smartwarehouse.api.controller;

import com.smartwarehouse.api.dto.*;
import com.smartwarehouse.api.entity.Role;
import com.smartwarehouse.api.entity.Worker;
import com.smartwarehouse.api.repository.WorkerRepository;
import com.smartwarehouse.api.security.JwtService;
import com.smartwarehouse.api.service.AuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthenticationManager authenticationManager;
    private final JwtService jwtService;
    private final WorkerRepository workerRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuthService authService;

    @PostMapping("/register")
    public ResponseEntity<String> register(@Valid @RequestBody WorkerRequestDto request) {
        Worker worker = new Worker();
        worker.setFirstName(request.getFirstName());
        worker.setLastName(request.getLastName());
        worker.setEmail(request.getEmail());
        worker.setUsername(request.getEmail());
        worker.setPassword(passwordEncoder.encode(request.getPassword()));
        worker.setPhoneNumber(request.getPhoneNumber());
        worker.setRole(request.getRole() != null ? request.getRole() : Role.WORKER);

        workerRepository.save(worker);
        return ResponseEntity.ok("Personel başarıyla kaydedildi.");
    }

    @PostMapping("/login")
    public ResponseEntity<AuthResponseDto> login(@Valid @RequestBody AuthRequestDto request) {
        System.out.println("Giriş Denemesi: " + request.getEmail());

        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.getEmail(), request.getPassword())
        );
        Worker worker = workerRepository.findByEmail(request.getEmail()).orElseThrow();

        String token = jwtService.generateToken(worker);
        String fullName = worker.getFirstName() + " " + worker.getLastName();
        return ResponseEntity.ok(new AuthResponseDto(token, worker.getId(), fullName));
    }

    @PostMapping("/forgot-password")
    public ResponseEntity<?> forgotPassword(@Valid @RequestBody ForgotPasswordRequestDto request) {
        boolean isSms = "SMS".equalsIgnoreCase(request.getDeliveryMethod());
        if (!isSms) {
            boolean userExists = workerRepository.findByEmail(request.getContactInfo()).isPresent();
            if (!userExists) {
                return ResponseEntity.badRequest().body(Map.of("error", "Bu e-posta adresi sistemde kayıtlı değil."));
            }
        }
        authService.generateAndSendOtp(request.getContactInfo(), isSms);

        String mesaj = isSms ? "Doğrulama kodu telefonunuza SMS olarak gönderildi." : "Doğrulama kodu e-posta adresinize gönderildi.";
        return ResponseEntity.ok(Map.of("message", mesaj));
    }

    @PostMapping("/verify-otp")
    public ResponseEntity<?> verifyOtp(@RequestBody VerifyOtpRequestDto request) {
        boolean isValid = authService.verifyOtp(request.getContactInfo(), request.getOtpCode());

        if (isValid) {
            return ResponseEntity.ok(Map.of("message", "Kod doğrulandı. Yeni şifrenizi belirleyebilirsiniz."));
        } else {
            return ResponseEntity.badRequest().body(Map.of("error", "Geçersiz veya süresi dolmuş kod."));
        }
    }

    @PostMapping("/reset-password")
    public ResponseEntity<?> resetPassword(@Valid @RequestBody ResetPasswordRequestDto request) {
        try {
            authService.resetPassword(request.getContactInfo(), request.getNewPassword());
            return ResponseEntity.ok(Map.of("message", "Şifreniz başarıyla güncellendi."));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }
}