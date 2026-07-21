package com.smartwarehouse.api.service;

import com.smartwarehouse.api.dto.StockMovementResponseDto;
import com.smartwarehouse.api.entity.Product;
import com.smartwarehouse.api.entity.StockMovement;
import com.smartwarehouse.api.entity.StockMovementType;
import com.smartwarehouse.api.repository.StockMovementRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.List;

@Service
@RequiredArgsConstructor
public class StockMovementService {
    private final StockMovementRepository stockMovementRepository;

    public void record(Product product, int quantity, StockMovementType type, String reason) {
        if (quantity <= 0) return;
        StockMovement movement = new StockMovement();
        movement.setProductId(product.getId());
        movement.setProductName(product.getName());
        movement.setShelfCode(product.getShelf() == null ? "-" : product.getShelf().getShelfCode());
        movement.setQuantity(quantity);
        movement.setType(type);
        movement.setReason(reason);
        stockMovementRepository.save(movement);
    }

    public List<StockMovementResponseDto> getMovements(LocalDate from, LocalDate to) {
        List<StockMovement> movements = from == null || to == null
                ? stockMovementRepository.findAllByOrderByCreatedAtAsc()
                : stockMovementRepository.findAllByCreatedAtBetweenOrderByCreatedAtAsc(from.atStartOfDay(), to.plusDays(1).atStartOfDay().minusNanos(1));
        return movements.stream().map(this::toDto).toList();
    }

    private StockMovementResponseDto toDto(StockMovement movement) {
        StockMovementResponseDto dto = new StockMovementResponseDto();
        dto.setId(movement.getId());
        dto.setProductId(movement.getProductId());
        dto.setProductName(movement.getProductName());
        dto.setShelfCode(movement.getShelfCode());
        dto.setQuantity(movement.getQuantity());
        dto.setType(movement.getType().name());
        dto.setReason(movement.getReason());
        dto.setCreatedAt(movement.getCreatedAt());
        return dto;
    }
}
