package com.smartwarehouse.api.service;

import com.smartwarehouse.api.entity.PickTask;
import com.smartwarehouse.api.entity.Shelf;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;
@Slf4j
@Service
public class TaskSortingService {

    public void sortTasksByDistance(List<PickTask> tasks, Shelf workerLocation) {
        if (tasks == null || tasks.isEmpty()) return;
        quickSort(tasks, 0, tasks.size() - 1, workerLocation);
    }

    private void quickSort(List<PickTask> tasks, int low, int high, Shelf workerLocation) {
        if (low < high) {
            int pivotIndex = partition(tasks, low, high, workerLocation);

            quickSort(tasks, low, pivotIndex - 1, workerLocation);
            quickSort(tasks, pivotIndex + 1, high, workerLocation);
        }
    }

    private int partition(List<PickTask> tasks, int low, int high, Shelf workerLocation) {

        PickTask pivotTask = tasks.get(high);
        Shelf pivotShelf = getFirstShelfFromTask(pivotTask);
        int pivotDistance = calculateManhattanDistance(workerLocation, pivotShelf);

        int i = (low - 1);

        for (int j = low; j < high; j++) {
            Shelf currentShelf = getFirstShelfFromTask(tasks.get(j));
            int currentDistance = calculateManhattanDistance(workerLocation, currentShelf);

            if (currentDistance < pivotDistance) {
                i++;
                swap(tasks, i, j);
            }
        }

        swap(tasks, i + 1, high);

        return i + 1;
    }

    private Shelf getFirstShelfFromTask(PickTask task) {
        if (task != null && task.getItems() != null && !task.getItems().isEmpty()) {
            return task.getItems().get(0).getProduct().getShelf();
        }
        return null;
    }

    private void swap(List<PickTask> tasks, int i, int j) {
        PickTask temp = tasks.get(i);
        tasks.set(i, tasks.get(j));
        tasks.set(j, temp);
    }

    private int calculateManhattanDistance(Shelf s1, Shelf s2) {
        if (s1 == null || s2 == null) return Integer.MAX_VALUE;

        return Math.abs(s1.getCoordinateX() - s2.getCoordinateX()) +
                Math.abs(s1.getCoordinateY() - s2.getCoordinateY());
    }
}