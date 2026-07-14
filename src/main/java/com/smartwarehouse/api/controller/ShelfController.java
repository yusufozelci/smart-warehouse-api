package com.smartwarehouse.api.controller;

import com.smartwarehouse.api.entity.Shelf;
import com.smartwarehouse.api.repository.ShelfRepository;
import com.smartwarehouse.api.service.WarehouseGraphService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/shelves")
public class ShelfController {

    private final ShelfRepository shelfRepository;
    private final WarehouseGraphService warehouseGraphService;

    @PostMapping
    public ResponseEntity<Shelf> createShelf(@RequestBody Shelf shelf) {
        Shelf savedShelf = shelfRepository.save(shelf);
        return new ResponseEntity<>(savedShelf, HttpStatus.CREATED);
    }

    @GetMapping
    public ResponseEntity<List<Shelf>> getAllShelves() {
        return ResponseEntity.ok(shelfRepository.findAll());
    }

    @GetMapping("/{id}/nearest")
    public ResponseEntity<Shelf> getNearestShelf(@PathVariable Long id) {
        Shelf currentShelf = shelfRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Raf bulunamadı. ID: " + id));

        Shelf nearestShelf = warehouseGraphService.findNearestAvailableShelf(currentShelf);

        if (nearestShelf == null) {
            return ResponseEntity.notFound().build();
        }

        return ResponseEntity.ok(nearestShelf);
    }
}