package com.smartwarehouse.api.mapper;

import com.smartwarehouse.api.dto.PickTaskItemResponseDto;
import com.smartwarehouse.api.entity.PickTaskItem;
import org.springframework.stereotype.Component;

@Component
public class PickTaskItemMapper {

    public PickTaskItemResponseDto toResponseDto(PickTaskItem item) {
        if (item == null) {
            return null;
        }

        PickTaskItemResponseDto dto = new PickTaskItemResponseDto();
        dto.setId(item.getId());
        dto.setQuantity(item.getQuantity());
        dto.setPicked(item.isPicked());
        dto.setCreatedAt(item.getCreatedAt());
        dto.setUpdatedAt(item.getUpdatedAt());

        if (item.getProduct() != null) {
            dto.setProductId(item.getProduct().getId());
            dto.setProductName(item.getProduct().getName());
            dto.setSku(item.getProduct().getSku());
            dto.setStockQuantity(item.getProduct().getStockQuantity());

            if (item.getProduct().getShelf() != null) {
                dto.setShelfCode(item.getProduct().getShelf().getShelfCode());
            }
        }

        return dto;
    }
}