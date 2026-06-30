package com.smartwarehouse.api.service;

import com.smartwarehouse.api.dto.WorkerRequestDto;
import com.smartwarehouse.api.dto.WorkerResponseDto;
import com.smartwarehouse.api.entity.Worker;
import com.smartwarehouse.api.mapper.WorkerMapper;
import com.smartwarehouse.api.repository.WorkerRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class WorkerService {

    private final WorkerRepository workerRepository;
    private final WorkerMapper workerMapper;

    public WorkerService(WorkerRepository workerRepository, WorkerMapper workerMapper) {
        this.workerRepository = workerRepository;
        this.workerMapper = workerMapper;
    }

    @Transactional
    public WorkerResponseDto addWorker(WorkerRequestDto request) {
        Worker worker;
        try {
            worker = workerMapper.toEntity(request);
        } catch (IllegalArgumentException e) {
            throw new RuntimeException("Geçersiz rol türü! Yalnızca ADMIN veya PERSONNEL girilebilir.");
        }

        Worker savedWorker = workerRepository.save(worker);

        return workerMapper.toResponseDto(savedWorker);
    }
}