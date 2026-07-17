package com.smartwarehouse.api.mapper;

import com.smartwarehouse.api.dto.PickTaskResponseDto;
import com.smartwarehouse.api.entity.PickTask;
import org.springframework.stereotype.Component;
import java.util.stream.Collectors;

@Component
public class PickTaskMapper {

    private final PickTaskItemMapper itemMapper;

    public PickTaskMapper(PickTaskItemMapper itemMapper) {
        this.itemMapper = itemMapper;
    }

    public PickTaskResponseDto toResponseDto(PickTask pickTask) {
        if (pickTask == null) return null;
        PickTaskResponseDto dto = new PickTaskResponseDto();
        dto.setId(pickTask.getId());
        dto.setStatus(pickTask.getStatus().name());

        if (pickTask.getIsDeleted() != null && pickTask.getIsDeleted()) {
            dto.setStatus("DELETED");
        } else {
            dto.setStatus(pickTask.getStatus().name());
        }

        dto.setCreatedAt(pickTask.getCreatedAt());
        dto.setUpdatedAt(pickTask.getUpdatedAt());
        if (pickTask.getAssignedWorker() != null) {
            String fullName = pickTask.getAssignedWorker().getFirstName() + " " +
                    pickTask.getAssignedWorker().getLastName();
            dto.setAssignedWorkerName(fullName);
        } else {
            dto.setAssignedWorkerName("Atanmamış");
        }

        if (pickTask.getItems() != null) {
            dto.setItems(pickTask.getItems().stream()
                    .map(itemMapper::toResponseDto)
                    .collect(Collectors.toList()));
        }

        return dto;
    }
}