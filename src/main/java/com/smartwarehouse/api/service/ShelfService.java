package com.smartwarehouse.api.service;

import com.smartwarehouse.api.dto.ShelfRequestDto;
import com.smartwarehouse.api.dto.ShelfResponseDto;
import com.smartwarehouse.api.entity.Shelf;
import com.smartwarehouse.api.mapper.ShelfMapper;
import com.smartwarehouse.api.repository.ShelfRepository;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

@Service
public class ShelfService {

    private final ShelfRepository shelfRepository;
    private final ShelfMapper shelfMapper;

    public ShelfService(ShelfRepository shelfRepository, ShelfMapper shelfMapper) {
        this.shelfRepository = shelfRepository;
        this.shelfMapper = shelfMapper;
    }

    @Cacheable(value = "shelves")
    public List<Shelf> getAllShelves() {
        return shelfRepository.findAll();
    }

    @Transactional
    @CacheEvict(value = "shelves", allEntries = true)
    public ShelfResponseDto addShelf(ShelfRequestDto request) {
        if (shelfRepository.findByShelfCode(request.getShelfCode()).isPresent()) {
            throw new RuntimeException("Bu raf kodu sistemde zaten mevcut!");
        }

        Shelf shelf = shelfMapper.toEntity(request);
        Shelf savedShelf = shelfRepository.save(shelf);

        return shelfMapper.toResponseDto(savedShelf);
    }
    @Transactional
    @CacheEvict(value = "shelves", allEntries = true)
    public List<ShelfResponseDto> createShelfMatrix(int rows, int cols) {
        List<Shelf> shelves = new ArrayList<>();
        for (int i = 1; i <= rows; i++) {
            for (int j = 1; j <= cols; j++) {
                String shelfCode = "R" + i + "-C" + j;
                if (shelfRepository.findByShelfCode(shelfCode).isPresent()) {
                    continue;
                }
                Shelf shelf = new Shelf();
                shelf.setShelfCode(shelfCode);
                shelf.setCoordinateX(i);
                shelf.setCoordinateY(j);
                shelves.add(shelf);
            }
        }
        shelfRepository.saveAll(shelves);
        return shelves.stream().map(shelfMapper::toResponseDto).toList();
    }
}