package com.smartwarehouse.api.mapper;

import com.smartwarehouse.api.dto.ShelfRequestDto;
import com.smartwarehouse.api.dto.ShelfResponseDto;
import com.smartwarehouse.api.entity.Shelf;
import org.springframework.stereotype.Component;

@Component
public class ShelfMapper {

    public ShelfResponseDto toResponseDto(Shelf shelf) {
        if (shelf == null) {
            return null;
        }

        ShelfResponseDto dto = new ShelfResponseDto();
        dto.setId(shelf.getId());
        dto.setShelfCode(shelf.getShelfCode());
        dto.setCoordinateX(shelf.getCoordinateX());
        dto.setCoordinateY(shelf.getCoordinateY());
        dto.setFloor(shelf.getFloor());

        return dto;
    }

    public Shelf toEntity(ShelfRequestDto dto) {
        if (dto == null) {
            return null;
        }

        Shelf shelf = new Shelf();
        shelf.setShelfCode(dto.getShelfCode());
        shelf.setCoordinateX(dto.getCoordinateX());
        shelf.setCoordinateY(dto.getCoordinateY());
        shelf.setFloor(dto.getFloor());

        return shelf;
    }
}