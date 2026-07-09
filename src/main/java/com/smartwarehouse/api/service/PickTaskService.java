package com.smartwarehouse.api.service;

import com.smartwarehouse.api.dto.OrderEventDto;
import com.smartwarehouse.api.dto.PickTaskItemRequestDto;
import com.smartwarehouse.api.dto.PickTaskRequestDto;
import com.smartwarehouse.api.dto.PickTaskResponseDto;
import com.smartwarehouse.api.entity.*;
import com.smartwarehouse.api.mapper.PickTaskMapper;
import com.smartwarehouse.api.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

@Service
public class PickTaskService {

    private final PickTaskRepository pickTaskRepository;
    private final PickTaskItemRepository pickTaskItemRepository;
    private final ProductRepository productRepository;
    private final WorkerRepository workerRepository;
    private final ShelfRepository shelfRepository;
    private final PickTaskMapper pickTaskMapper;

    private final TaskSortingService taskSortingService;
    private final RouteOptimizationService routeOptimizationService;

    public PickTaskService(PickTaskRepository pickTaskRepository, PickTaskItemRepository pickTaskItemRepository,
                           ProductRepository productRepository,
                           WorkerRepository workerRepository,
                           ShelfRepository shelfRepository,
                           PickTaskMapper pickTaskMapper,
                           TaskSortingService taskSortingService,
                           RouteOptimizationService routeOptimizationService) {
        this.pickTaskRepository = pickTaskRepository;
        this.pickTaskItemRepository = pickTaskItemRepository;
        this.productRepository = productRepository;
        this.workerRepository = workerRepository;
        this.shelfRepository = shelfRepository;
        this.pickTaskMapper = pickTaskMapper;
        this.taskSortingService = taskSortingService;
        this.routeOptimizationService = routeOptimizationService;
    }

    @Transactional
    public PickTaskResponseDto createPickTask(PickTaskRequestDto request) {
        PickTask task = new PickTask();
        task.setStatus(TaskStatus.PENDING);

        if (request.getAssignedWorkerId() != null) {
            Worker worker = workerRepository.findById(request.getAssignedWorkerId())
                    .orElseThrow(() -> new RuntimeException("Personel bulunamadı!"));
            task.setAssignedWorker(worker);
        }

        for (PickTaskItemRequestDto itemDto : request.getItems()) {
            Product product = productRepository.findById(itemDto.getProductId())
                    .orElseThrow(() -> new RuntimeException("Ürün bulunamadı ID: " + itemDto.getProductId()));

            if (product.getStockQuantity() < itemDto.getQuantity()) {
                throw new RuntimeException("Yetersiz stok! Ürün: " + product.getName() + " Mevcut: " + product.getStockQuantity());
            }

            PickTaskItem item = new PickTaskItem();
            item.setProduct(product);
            item.setQuantity(itemDto.getQuantity());
            item.setPicked(false);

            task.addItem(item);
        }

        PickTask savedTask = pickTaskRepository.save(task);

        return pickTaskMapper.toResponseDto(savedTask);
    }

    @Transactional
    public PickTaskResponseDto assignClosestTaskToWorker(Long workerId, Long currentShelfId) {

        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new RuntimeException("Personel bulunamadı!"));

        Shelf currentWorkerLocation = shelfRepository.findById(currentShelfId)
                .orElseThrow(() -> new RuntimeException("Personelin bulunduğu raf bulunamadı!"));

        List<Shelf> allShelves = shelfRepository.findAll();

        List<PickTask> pendingTasks = pickTaskRepository.findByStatus(TaskStatus.PENDING);

        if (pendingTasks == null || pendingTasks.isEmpty()) {
            throw new RuntimeException("Sistemde atanacak bekleyen görev bulunmamaktadır.");
        }

        taskSortingService.sortTasksByDistance(pendingTasks, currentWorkerLocation);

        PickTask closestTask = pendingTasks.get(0);
        closestTask.setAssignedWorker(worker);

        Shelf targetShelf = closestTask.getItems().get(0).getProduct().getShelf();
        List<Shelf> shortestRoute = routeOptimizationService.calculateShortestPathDijkstra(
                currentWorkerLocation, targetShelf, allShelves
        );

        PickTask savedTask = pickTaskRepository.save(closestTask);

        return pickTaskMapper.toResponseDto(savedTask);
    }

    @Transactional
    public void createTaskFromOrder(OrderEventDto orderEvent) {
        PickTask task = new PickTask();
        task.setStatus(TaskStatus.PENDING);
        task.setTaskCode((orderEvent.getOrderId() != null) ? orderEvent.getOrderId() : "TASK-" + System.currentTimeMillis());

        for (Long productId : orderEvent.getProductIds()) {
            Product product = productRepository.findById(productId)
                    .orElseThrow(() -> new RuntimeException("Ürün bulunamadı!"));

            PickTaskItem item = new PickTaskItem();
            item.setProduct(product);
            item.setQuantity(1);
            item.setPicked(false);


            task.addItem(item);
        }

        pickTaskRepository.save(task);
    }
    @Transactional(readOnly = true)
    public List<PickTask> findAllTasks() {
        return pickTaskRepository.findAll();
    }
    @Transactional(readOnly = true)
    public List<PickTask> getPendingTasksForWorker(Worker worker) {
        return pickTaskRepository.findByAssignedWorkerAndStatus(worker, TaskStatus.PENDING);
    }
    @Transactional
    public PickTaskResponseDto completePickTask(Long taskId) {
        PickTask task = pickTaskRepository.findById(taskId)
                .orElseThrow(() -> new RuntimeException("Görev bulunamadı! ID: " + taskId));

        if (task.getStatus() == TaskStatus.COMPLETED) {
            throw new RuntimeException("Bu görev zaten tamamlanmış!");
        }

        task.setStatus(TaskStatus.COMPLETED);

        for (PickTaskItem item : task.getItems()) {
            item.setPicked(true);

        }

        PickTask savedTask = pickTaskRepository.save(task);
        return pickTaskMapper.toResponseDto(savedTask);
    }

    @Transactional(readOnly = true)
    public List<PickTask> getCompletedTasksForWorker(Worker worker) {
        return pickTaskRepository.findByAssignedWorkerAndStatus(worker, TaskStatus.COMPLETED);
    }
}
