package com.smartwarehouse.api.service;

import com.smartwarehouse.api.dto.WorkerRequestDto;
import com.smartwarehouse.api.dto.WorkerResponseDto;
import com.smartwarehouse.api.entity.Role;
import com.smartwarehouse.api.entity.Worker;
import com.smartwarehouse.api.mapper.WorkerMapper;
import com.smartwarehouse.api.repository.WorkerRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class WorkerService {

    private final WorkerRepository workerRepository;
    private final WorkerMapper workerMapper;
    private final PasswordEncoder passwordEncoder;

    @Transactional
    public WorkerResponseDto registerWorker(WorkerRequestDto request) {
        log.info("Yeni personel kaydı isteği alındı. Email: {}", request.getEmail());

        if (workerRepository.findByEmail(request.getEmail()).isPresent()) {
            log.error("Personel kayıt hatası: Bu email adresi zaten kullanılıyor! Email: {}", request.getEmail());
            throw new RuntimeException("Bu email adresi zaten kullanılıyor.");
        }

        Worker worker = new Worker();
        worker.setFirstName(request.getFirstName());
        worker.setLastName(request.getLastName());
        worker.setEmail(request.getEmail());
        worker.setUsername(request.getEmail());
        worker.setPassword(passwordEncoder.encode(request.getPassword()));
        worker.setRole(request.getRole());
        worker.setIsDeleted(false);

        Worker savedWorker = workerRepository.save(worker);
        log.info("Yeni personel başarıyla kaydedildi. ID: {}", savedWorker.getId());

        return workerMapper.toResponseDto(savedWorker);
    }

    @Transactional(readOnly = true)
    public List<WorkerResponseDto> getAllWorkers() {
        return workerRepository.findAllByIsDeletedFalse()
                .stream()
                .map(workerMapper::toResponseDto)
                .toList();
    }

    public void deleteWorker(Long id) {
        Worker worker = workerRepository.findById(id).orElseThrow();
        worker.setEmail("silindi_" + System.currentTimeMillis() + "_" + worker.getEmail());
        worker.setUsername(worker.getEmail());
        workerRepository.save(worker);
        workerRepository.delete(worker);
    }

    public Worker updateWorker(Long id, WorkerRequestDto request) {
        Worker worker = workerRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Personel bulunamadı!"));
        if (request.getFirstName() != null && !request.getFirstName().trim().isEmpty()) {
            worker.setFirstName(request.getFirstName());
        }
        if (request.getLastName() != null && !request.getLastName().trim().isEmpty()) {
            worker.setLastName(request.getLastName());
        }
        if (request.getEmail() != null && !request.getEmail().trim().isEmpty()) {
            worker.setEmail(request.getEmail());
            worker.setUsername(request.getEmail());
        }
        if (request.getPhoneNumber() != null && !request.getPhoneNumber().trim().isEmpty()) {
            worker.setPhoneNumber(request.getPhoneNumber());
        }
        if (request.getRole() != null) {
            worker.setRole(request.getRole());
        }
        return workerRepository.save(worker);
    }

    public Worker findWorkerByContact(String contactInfo, String formattedNumber) {
        if (contactInfo.contains("@")) {
            return workerRepository.findByEmail(contactInfo)
                    .orElseThrow(() -> new RuntimeException("Kullanıcı bulunamadı (Email)."));
        } else {
            return workerRepository.findByPhoneNumber(formattedNumber)
                    .orElseThrow(() -> new RuntimeException("Kullanıcı bulunamadı (Telefon)."));
        }
    }

    @Transactional
    public void updatePassword(Worker worker, String newPassword) {
        worker.setPassword(passwordEncoder.encode(newPassword));
        workerRepository.save(worker);
    }
}