package com.smartwarehouse.api;

import com.smartwarehouse.api.entity.Shelf;
import com.smartwarehouse.api.service.RouteOptimizationService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.Arrays;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class RouteOptimizationServiceTest {

    private RouteOptimizationService routeOptimizationService;

    @BeforeEach
    void setUp() {

        routeOptimizationService = new RouteOptimizationService();
    }

    @Test
    void calculateShortestPathDijkstra_ShouldReturnCorrectPath() {
        Shelf startShelf = new Shelf();
        startShelf.setId(1L);
        startShelf.setCoordinateX(0);
        startShelf.setCoordinateY(0);

        Shelf middleShelf = new Shelf();
        middleShelf.setId(2L);
        middleShelf.setCoordinateX(0);
        middleShelf.setCoordinateY(5);

        Shelf targetShelf = new Shelf();
        targetShelf.setId(3L);
        targetShelf.setCoordinateX(5);
        targetShelf.setCoordinateY(5);

        List<Shelf> allShelves = Arrays.asList(startShelf, middleShelf, targetShelf);

        List<Shelf> path = routeOptimizationService.calculateShortestPathDijkstra(startShelf, targetShelf, allShelves);

        assertNotNull(path, "Rota null dönmemeli");

        assertEquals(2, path.size(), "Algoritma doğrudan en kısa rotayı (start -> target) bulmalı");

        assertEquals(startShelf.getId(), path.get(0).getId(), "İlk durak başlangıç rafı olmalı");
        assertEquals(targetShelf.getId(), path.get(1).getId(), "Son durak hedef raf olmalı");
    }
}