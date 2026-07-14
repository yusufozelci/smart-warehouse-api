package com.smartwarehouse.api.controller;

import com.smartwarehouse.api.dto.AuthRequestDto;
import com.smartwarehouse.api.dto.AuthResponseDto;
import com.smartwarehouse.api.dto.WorkerRequestDto;
import com.smartwarehouse.api.entity.Role;
import com.smartwarehouse.api.entity.Worker;
import com.smartwarehouse.api.repository.WorkerRepository;
import com.smartwarehouse.api.security.JwtService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthenticationManager authenticationManager;
    private final JwtService jwtService;
    private final WorkerRepository workerRepository;
    private final PasswordEncoder passwordEncoder;

    @PostMapping("/register")
    public ResponseEntity<String> register(@RequestBody WorkerRequestDto request) {
        Worker worker = new Worker();
        worker.setFirstName(request.getFirstName());
        worker.setLastName(request.getLastName());
        worker.setEmail(request.getEmail());
        worker.setUsername(request.getEmail());
        worker.setPassword(passwordEncoder.encode(request.getPassword()));
        worker.setRole(request.getRole() != null ? request.getRole() : Role.WORKER);

        workerRepository.save(worker);
        return ResponseEntity.ok("Personel başarıyla kaydedildi.");
    }

    @PostMapping("/login")
    public ResponseEntity<AuthResponseDto> login(@RequestBody AuthRequestDto request) {
        System.out.println("Giriş Denemesi: " + request.getEmail());
        System.out.println("Gelen Şifre: '" + request.getPassword() + "'");

        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.getEmail(), request.getPassword())
        );
        Worker worker = workerRepository.findByEmail(request.getEmail()).orElseThrow();

        String token = jwtService.generateToken(worker);
        String fullName = worker.getFirstName() + " " + worker.getLastName();
        return ResponseEntity.ok(new AuthResponseDto(token, worker.getId(), fullName));
    }
}