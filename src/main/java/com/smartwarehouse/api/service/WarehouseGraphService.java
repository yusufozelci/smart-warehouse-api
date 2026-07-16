package com.smartwarehouse.api.service;

import com.smartwarehouse.api.entity.Shelf;
import com.smartwarehouse.api.repository.ShelfRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;
@Slf4j
@RequiredArgsConstructor
@Service
public class WarehouseGraphService {

    private final ShelfRepository shelfRepository;

    public int calculateDistance(Shelf sourceShelf, Shelf targetShelf) {
        return Math.abs(sourceShelf.getCoordinateX() - targetShelf.getCoordinateX()) +
                Math.abs(sourceShelf.getCoordinateY() - targetShelf.getCoordinateY());
    }

    public Shelf findNearestAvailableShelf(Shelf currentShelf) {
        List<Shelf> allShelves = shelfRepository.findAll();

        Shelf nearestShelf = null;
        int minDistance = Integer.MAX_VALUE;

        for (Shelf targetShelf : allShelves) {
            if (!targetShelf.getId().equals(currentShelf.getId()) /* && targetShelf.getProducts().size() < 50 */) {
                int distance = calculateDistance(currentShelf, targetShelf);
                if (distance < minDistance) {
                    minDistance = distance;
                    nearestShelf = targetShelf;
                }
            }
        }
        return nearestShelf;
    }
}