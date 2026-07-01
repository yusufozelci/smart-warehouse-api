package com.smartwarehouse.api.service;

import com.smartwarehouse.api.dto.WorkerRequestDto;
import com.smartwarehouse.api.dto.WorkerResponseDto;
import com.smartwarehouse.api.entity.Worker;
import com.smartwarehouse.api.mapper.WorkerMapper;
import com.smartwarehouse.api.repository.WorkerRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class WorkerService {

    private final WorkerRepository workerRepository;
    private final WorkerMapper workerMapper;
    private final PasswordEncoder passwordEncoder;

    @Transactional
    public WorkerResponseDto registerWorker(WorkerRequestDto request) {

        if (workerRepository.findByEmail(request.getEmail()).isPresent()) {
            throw new RuntimeException("Bu email adresi zaten kullanılıyor.");
        }

        Worker worker = new Worker();
        worker.setFirstName(request.getFirstName());
        worker.setLastName(request.getLastName());
        worker.setEmail(request.getEmail());
        worker.setPassword(passwordEncoder.encode(request.getPassword()));
        worker.setRole(request.getRole());

        Worker savedWorker = workerRepository.save(worker);

        return workerMapper.toResponseDto(savedWorker);
    }
}
