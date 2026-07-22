package com.smartwarehouse.api.mapper;

import com.smartwarehouse.api.dto.PickTaskRequestDto;
import com.smartwarehouse.api.dto.PickTaskResponseDto;
import com.smartwarehouse.api.entity.PickTask;
import com.smartwarehouse.api.entity.TaskStatus;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import java.util.stream.Collectors;
@RequiredArgsConstructor
@Component
public class PickTaskMapper {

    private final PickTaskItemMapper itemMapper;

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

        dto.setCancelReason(pickTask.getCancelReason());
        dto.setCancelledBy(pickTask.getCancelledBy());
        if (pickTask.getItems() != null) {
            dto.setItems(pickTask.getItems().stream()
                    .map(itemMapper::toResponseDto)
                    .collect(Collectors.toList()));
        }

        if (pickTask.getStatus() == TaskStatus.COMPLETED && pickTask.getCreatedAt() != null && pickTask.getUpdatedAt() != null) {
            java.time.Duration duration = java.time.Duration.between(pickTask.getCreatedAt(), pickTask.getUpdatedAt());
            long minutes = duration.toMinutes();
            long hours = duration.toHours();

            String durationStr = (hours > 0) ? hours + " sa " + (minutes % 60) + " dk" : minutes + " dk";
            dto.setCompletionDuration(durationStr);
        } else {
            dto.setCompletionDuration("-");
        }

        return dto;
    }
}