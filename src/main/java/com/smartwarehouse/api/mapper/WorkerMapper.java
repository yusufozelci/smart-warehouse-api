package com.smartwarehouse.api.mapper;

import com.smartwarehouse.api.dto.WorkerRequestDto;
import com.smartwarehouse.api.dto.WorkerResponseDto;
import com.smartwarehouse.api.entity.Role;
import com.smartwarehouse.api.entity.Worker;
import org.springframework.stereotype.Component;

@Component
public class WorkerMapper {

    public WorkerResponseDto toResponseDto(Worker worker) {
        if (worker == null) {
            return null;
        }

        WorkerResponseDto dto = new WorkerResponseDto();
        dto.setId(worker.getId());
        dto.setFirstName(worker.getFirstName());
        dto.setLastName(worker.getLastName());
        dto.setRole(worker.getRole().name());

        return dto;
    }

    public Worker toEntity(WorkerRequestDto dto) {
        if (dto == null) {
            return null;
        }

        Worker worker = new Worker();
        worker.setFirstName(dto.getFirstName());
        worker.setLastName(dto.getLastName());
        worker.setRole(dto.getRole());

        return worker;
    }
}
