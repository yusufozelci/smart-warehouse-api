package com.smartwarehouse.api.service;

import com.smartwarehouse.api.dto.OrderEventDto;
import com.smartwarehouse.api.dto.PickTaskItemRequestDto;
import com.smartwarehouse.api.dto.PickTaskRequestDto;
import com.smartwarehouse.api.dto.PickTaskResponseDto;
import com.smartwarehouse.api.entity.*;
import com.smartwarehouse.api.mapper.PickTaskMapper;
import com.smartwarehouse.api.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.messaging.simp.SimpMessagingTemplate;

import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Slf4j
@RequiredArgsConstructor
@Service
public class PickTaskService {

    private final PickTaskRepository pickTaskRepository;
    private final SimpMessagingTemplate messagingTemplate;
    private final PickTaskItemRepository pickTaskItemRepository;
    private final ProductRepository productRepository;
    private final WorkerRepository workerRepository;
    private final ShelfRepository shelfRepository;
    private final PickTaskMapper pickTaskMapper;
    private final TaskSortingService taskSortingService;
    private final ProductService productService;

    @Transactional
    public PickTaskResponseDto createPickTask(PickTaskRequestDto request) {
        log.info("Yeni görev oluşturuluyor...");
        PickTask task = new PickTask();
        task.setStatus(TaskStatus.PENDING);
        task.setTaskCode("TASK-" + System.currentTimeMillis());

        if (request.getAssignedWorkerId() != null) {
            Worker worker = workerRepository.findById(request.getAssignedWorkerId())
                    .orElseThrow(() -> {
                        log.error("Görev oluşturma hatası: Personel bulunamadı! ID: {}", request.getAssignedWorkerId());
                        return new RuntimeException("Personel bulunamadı!");
                    });
            task.setAssignedWorker(worker);
        }

        for (PickTaskItemRequestDto itemDto : request.getItems()) {
            Product product = productRepository.findById(itemDto.getProductId())
                    .orElseThrow(() -> {
                        log.error("Görev oluşturma hatası: Ürün bulunamadı! ID: {}", itemDto.getProductId());
                        return new RuntimeException("Ürün bulunamadı ID: " + itemDto.getProductId());
                    });

            PickTaskItem item = new PickTaskItem();
            item.setProduct(product);
            item.setQuantity(itemDto.getQuantity());
            item.setPicked(false);

            task.addItem(item);
        }

        PickTask savedTask = pickTaskRepository.save(task);
        log.info("Görev başarıyla oluşturuldu. Görev Kodu: {}", savedTask.getTaskCode());
        return pickTaskMapper.toResponseDto(savedTask);
    }

    @Transactional
    public PickTaskResponseDto assignClosestTaskToWorker(Long workerId, Long currentShelfId) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> {
                    log.error("Görev atama hatası: Personel bulunamadı! ID: {}", workerId);
                    return new RuntimeException("Personel bulunamadı!");
                });

        Shelf currentWorkerLocation = shelfRepository.findById(currentShelfId)
                .orElseThrow(() -> {
                    log.error("Görev atama hatası: Personelin bulunduğu raf bulunamadı! ID: {}", currentShelfId);
                    return new RuntimeException("Personelin bulunduğu raf bulunamadı!");
                });

        List<PickTask> unassignedTasks = pickTaskRepository.findAll().stream()
                .filter(t -> t.getStatus() == TaskStatus.PENDING)
                .filter(t -> t.getAssignedWorker() == null)
                .filter(t -> t.getItems() != null && !t.getItems().isEmpty())
                .collect(Collectors.toList());

        if (unassignedTasks.isEmpty()) {
            log.warn("Görev atama uyarısı: Sistemde atanacak bekleyen görev bulunmamaktadır.");
            throw new RuntimeException("Sistemde atanacak bekleyen görev bulunmamaktadır.");
        }

        taskSortingService.sortTasksByDistance(unassignedTasks, currentWorkerLocation);
        PickTask closestTask = unassignedTasks.get(0);
        closestTask.setAssignedWorker(worker);
        PickTask savedTask = pickTaskRepository.save(closestTask);

        log.info("Personel (ID: {}) için en yakın görev (Kodu: {}) başarıyla atandı.", workerId, savedTask.getTaskCode());
        return pickTaskMapper.toResponseDto(savedTask);
    }

    @Transactional
    public void createTaskFromOrder(OrderEventDto orderEvent) {
        log.info("Siparişten görev oluşturuluyor. Sipariş ID: {}", orderEvent.getOrderId());
        PickTask task = new PickTask();
        task.setStatus(TaskStatus.PENDING);
        task.setTaskCode((orderEvent.getOrderId() != null) ? orderEvent.getOrderId() : "TASK-" + System.currentTimeMillis());

        for (Long productId : orderEvent.getProductIds()) {
            Product product = productRepository.findById(productId)
                    .orElseThrow(() -> {
                        log.error("Siparişten görev oluşturma hatası: Ürün bulunamadı! ID: {}", productId);
                        return new RuntimeException("Ürün bulunamadı!");
                    });

            PickTaskItem item = new PickTaskItem();
            item.setProduct(product);
            item.setQuantity(1);
            item.setPicked(false);

            task.addItem(item);
        }

        pickTaskRepository.save(task);
        log.info("Sipariş kaynaklı görev başarıyla oluşturuldu.");
    }

    @Transactional(readOnly = true)
    public List<PickTask> findAllTasks() {
        return pickTaskRepository.findAll();
    }

    @Transactional(readOnly = true)
    public List<PickTask> getPendingTasksForWorker(Worker worker) {
        List<TaskStatus> activeStatuses = Arrays.asList(TaskStatus.PENDING, TaskStatus.IN_PROGRESS);
        return pickTaskRepository.findByAssignedWorkerAndStatusIn(worker, activeStatuses);
    }

    @Transactional
    public PickTaskResponseDto completePickTask(Long taskId) {
        PickTask task = pickTaskRepository.findById(taskId)
                .orElseThrow(() -> {
                    log.error("Görev tamamlama hatası: Görev bulunamadı! ID: {}", taskId);
                    return new RuntimeException("Görev bulunamadı! ID: " + taskId);
                });

        if (task.getStatus() == TaskStatus.COMPLETED) {
            log.warn("Görev tamamlama hatası: Görev zaten tamamlanmış! ID: {}", taskId);
            throw new RuntimeException("Bu görev zaten tamamlanmış!");
        }

        task.setStatus(TaskStatus.COMPLETED);

        for (PickTaskItem item : task.getItems()) {
            item.setPicked(true);
        }

        PickTask savedTask = pickTaskRepository.save(task);
        Map<String, Object> payload = new HashMap<>();
        payload.put("message", "Görev " + savedTask.getTaskCode() + " tamamlandı!");
        payload.put("boxId", savedTask.getId());
        payload.put("workerId", savedTask.getAssignedWorker() != null ? savedTask.getAssignedWorker().getId() : "Bilinmiyor");
        messagingTemplate.convertAndSend("/topic/manager/tasks", payload);

        log.info("Görev başarıyla tamamlandı ve WebSocket üzerinden bildirildi. Görev Kodu: {}", savedTask.getTaskCode());

        return pickTaskMapper.toResponseDto(savedTask);
    }

    @Transactional(readOnly = true)
    public List<PickTask> getCompletedTasksForWorker(Worker worker) {
        return pickTaskRepository.findByAssignedWorkerAndStatus(worker, TaskStatus.COMPLETED);
    }

    @Transactional
    public PickTaskResponseDto pickTaskItem(Long taskId, Long productId) {
        PickTask task = pickTaskRepository.findById(taskId)
                .orElseThrow(() -> {
                    log.error("Ürün toplama hatası: Görev bulunamadı! ID: {}", taskId);
                    return new RuntimeException("Görev bulunamadı!");
                });

        PickTaskItem itemToPick = task.getItems().stream()
                .filter(item -> item.getProduct().getId().equals(productId))
                .findFirst()
                .orElseThrow(() -> {
                    log.error("Ürün toplama hatası: Görev içerisinde bu ürün bulunamadı! Ürün ID: {}", productId);
                    return new RuntimeException("Ürün bulunamadı!");
                });

        itemToPick.setPicked(true);
        pickTaskItemRepository.save(itemToPick);
        productService.decreaseStock(productId, itemToPick.getQuantity());

        boolean allPicked = task.getItems().stream().allMatch(PickTaskItem::isPicked);
        String productName = itemToPick.getProduct().getName();
        String statusMessage = productName + " toplandı ve stoktan düşüldü!";
        task.setStatus(TaskStatus.IN_PROGRESS);

        if (allPicked) {
            statusMessage += " Çalışan onayı (Görevi Sonlandırma) bekleniyor...";
            log.info("Görev içerisindeki tüm ürünler toplandı. Görev sonlandırma bekleniyor. Görev ID: {}", taskId);
        }

        PickTask savedTask = pickTaskRepository.save(task);
        Map<String, Object> payload = new HashMap<>();
        payload.put("message", statusMessage);
        payload.put("taskId", savedTask.getId());
        payload.put("productId", productId);
        payload.put("workerId", savedTask.getAssignedWorker() != null ? savedTask.getAssignedWorker().getId() : "Bilinmiyor");
        payload.put("isTaskCompleted", false);

        messagingTemplate.convertAndSend("/topic/manager/tasks", payload);

        return pickTaskMapper.toResponseDto(savedTask);
    }

    @Transactional
    public PickTaskResponseDto assignTaskManually(Long taskId, Long workerId) {
        PickTask task = pickTaskRepository.findById(taskId)
                .orElseThrow(() -> {
                    log.error("Manuel atama hatası: Görev bulunamadı! ID: {}", taskId);
                    return new RuntimeException("Görev bulunamadı!");
                });
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> {
                    log.error("Manuel atama hatası: Personel bulunamadı! ID: {}", workerId);
                    return new RuntimeException("Personel bulunamadı!");
                });

        task.setAssignedWorker(worker);
        PickTask savedTask = pickTaskRepository.save(task);
        log.info("Görev (ID: {}) manuel olarak Personele (ID: {}) atandı.", taskId, workerId);

        return pickTaskMapper.toResponseDto(savedTask);
    }
}