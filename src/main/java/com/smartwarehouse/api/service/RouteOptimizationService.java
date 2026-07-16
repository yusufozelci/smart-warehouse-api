package com.smartwarehouse.api.service;

import com.smartwarehouse.api.entity.Shelf;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.*;
@Slf4j
@Service
public class RouteOptimizationService {

    public List<Shelf> calculateShortestPathDijkstra(Shelf startShelf, Shelf targetShelf, List<Shelf> allShelves) {

        Map<Shelf, Integer> distances = new HashMap<>();
        Map<Shelf, Shelf> previousNodes = new HashMap<>();

        PriorityQueue<Shelf> unvisitedQueue = new PriorityQueue<>(Comparator.comparingInt(distances::get));

        for (Shelf shelf : allShelves) {
            if (shelf.equals(startShelf)) {
                distances.put(shelf, 0);
            } else {
                distances.put(shelf, Integer.MAX_VALUE);
            }
            unvisitedQueue.add(shelf);
        }

        while (!unvisitedQueue.isEmpty()) {

            Shelf currentShelf = unvisitedQueue.poll();
            if (currentShelf.equals(targetShelf)) {
                break;
            }
            for (Shelf neighbor : allShelves) {
                if (neighbor.equals(currentShelf)) continue;

                int edgeWeight = calculateManhattanDistance(currentShelf, neighbor);
                int alternativePathDistance = distances.get(currentShelf) + edgeWeight;


                if (alternativePathDistance < distances.get(neighbor)) {
                    distances.put(neighbor, alternativePathDistance);
                    previousNodes.put(neighbor, currentShelf);
                    unvisitedQueue.remove(neighbor);
                    unvisitedQueue.add(neighbor);
                }
            }
        }
        return buildPath(targetShelf, previousNodes);
    }

    private int calculateManhattanDistance(Shelf s1, Shelf s2) {
        return Math.abs(s1.getCoordinateX() - s2.getCoordinateX()) +
                Math.abs(s1.getCoordinateY() - s2.getCoordinateY());
    }

    private List<Shelf> buildPath(Shelf targetNode, Map<Shelf, Shelf> previousNodes) {
        List<Shelf> path = new ArrayList<>();
        Shelf step = targetNode;

        if (previousNodes.get(step) == null) {
            return path;
        }

        path.add(step);
        while (previousNodes.get(step) != null) {
            step = previousNodes.get(step);
            path.add(step);
        }

        Collections.reverse(path);
        return path;
    }
}