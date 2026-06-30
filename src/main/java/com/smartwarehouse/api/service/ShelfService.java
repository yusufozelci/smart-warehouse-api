package com.smartwarehouse.api.service;

import com.smartwarehouse.api.dto.ShelfRequestDto;
import com.smartwarehouse.api.dto.ShelfResponseDto;
import com.smartwarehouse.api.entity.Shelf;
import com.smartwarehouse.api.mapper.ShelfMapper;
import com.smartwarehouse.api.repository.ShelfRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ShelfService {

    private final ShelfRepository shelfRepository;
    private final ShelfMapper shelfMapper;

    public ShelfService(ShelfRepository shelfRepository, ShelfMapper shelfMapper) {
        this.shelfRepository = shelfRepository;
        this.shelfMapper = shelfMapper;
    }

    @Transactional
    public ShelfResponseDto addShelf(ShelfRequestDto request) {
        if (shelfRepository.findByShelfCode(request.getShelfCode()).isPresent()) {
            throw new RuntimeException("Bu raf kodu sistemde zaten mevcut!");
        }

        Shelf shelf = shelfMapper.toEntity(request);
        Shelf savedShelf = shelfRepository.save(shelf);

        return shelfMapper.toResponseDto(savedShelf);
    }
}