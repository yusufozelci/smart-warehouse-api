package com.smartwarehouse.api;

import com.smartwarehouse.api.entity.PickTask;
import com.smartwarehouse.api.entity.PickTaskItem;
import com.smartwarehouse.api.entity.Product;
import com.smartwarehouse.api.entity.Shelf;
import com.smartwarehouse.api.service.TaskSortingService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class TaskSortingServiceTest {

    private TaskSortingService taskSortingService;

    @BeforeEach
    void setUp() {
        taskSortingService = new TaskSortingService();
    }

    @Test
    void sortTasksByDistance_ShouldSortTasksFromClosestToFarthest() {
        Shelf workerLocation = new Shelf();
        workerLocation.setCoordinateX(0);
        workerLocation.setCoordinateY(0);

        PickTask farTask = createTaskWithShelfCoordinate(10, 10, 1L);
        PickTask closeTask = createTaskWithShelfCoordinate(2, 2, 2L);
        PickTask midTask = createTaskWithShelfCoordinate(5, 5, 3L);
        List<PickTask> pendingTasks = Arrays.asList(farTask, closeTask, midTask);


        taskSortingService.sortTasksByDistance(pendingTasks, workerLocation);


        assertNotNull(pendingTasks);
        assertEquals(3, pendingTasks.size());
        assertEquals(2L, pendingTasks.get(0).getId(), "İlk sıradaki görev EN YAKIN (ID: 2) olmalı");
        assertEquals(3L, pendingTasks.get(1).getId(), "İkinci sıradaki görev ORTA (ID: 3) olmalı");
        assertEquals(1L, pendingTasks.get(2).getId(), "Son sıradaki görev EN UZAK (ID: 1) olmalı");
    }

    private PickTask createTaskWithShelfCoordinate(int x, int y, Long taskId) {
        Shelf shelf = new Shelf();
        shelf.setCoordinateX(x);
        shelf.setCoordinateY(y);

        Product product = new Product();
        product.setShelf(shelf);

        PickTaskItem item = new PickTaskItem();
        item.setProduct(product);

        PickTask task = new PickTask();
        task.setId(taskId);

        List<PickTaskItem> items = new ArrayList<>();
        items.add(item);
        task.setItems(items);

        return task;
    }
}