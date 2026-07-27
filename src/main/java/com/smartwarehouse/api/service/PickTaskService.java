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
import org.springframework.security.access.AccessDeniedException;

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

        Map<String, Object> payload = new HashMap<>();
        payload.put("type", "TASK_CREATED");
        payload.put("message", "Yeni Görev Oluşturuldu: #" + savedTask.getId());
        payload.put("taskId", savedTask.getId());
        messagingTemplate.convertAndSend("/topic/manager/tasks", payload);
        log.info("Görev başarıyla oluşturuldu. Görev Kodu: {}", savedTask.getTaskCode());
        return pickTaskMapper.toResponseDto(savedTask);
    }

    @Transactional
    public PickTaskResponseDto assignClosestTaskToWorker(Long workerId, Long currentShelfId) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new RuntimeException("Personel bulunamadı!"));

        Shelf currentWorkerLocation = shelfRepository.findById(currentShelfId)
                .orElseThrow(() -> new RuntimeException("Personelin bulunduğu raf bulunamadı!"));

        List<PickTask> unassignedTasks = pickTaskRepository.findAll().stream()
                .filter(t -> t.getStatus() == TaskStatus.PENDING)
                .filter(t -> t.getAssignedWorker() == null)
                .filter(t -> t.getItems() != null && !t.getItems().isEmpty())
                .collect(Collectors.toList());

        if (unassignedTasks.isEmpty()) {
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
                    .orElseThrow(() -> new RuntimeException("Ürün bulunamadı!"));

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
        return pickTaskRepository.findAllByOrderByCreatedAtDesc();
    }

    @Transactional(readOnly = true)
    public List<PickTask> getPendingTasksForWorker(Worker worker) {
        List<TaskStatus> activeStatuses = Arrays.asList(TaskStatus.PENDING, TaskStatus.IN_PROGRESS);
        return pickTaskRepository.findByAssignedWorkerAndStatusInAndIsDeletedFalse(worker, activeStatuses);
    }

    @Transactional
    public PickTaskResponseDto completePickTask(Long taskId, Worker actor) {
        PickTask task = pickTaskRepository.findById(taskId)
                .orElseThrow(() -> new RuntimeException("Görev bulunamadı! ID: " + taskId));

        ensureWorkerCanOperate(task, actor);
        if (task.getIsDeleted() || task.getStatus() == TaskStatus.CANCELLED || task.getStatus() == TaskStatus.COMPLETED) {
            throw new RuntimeException("Bu görev zaten tamamlanmış!");
        }

        task.setStatus(TaskStatus.COMPLETED);
        String workerInfo = actor.getFirstName() + " " + actor.getLastName() + " (" + actor.getRole().name() + ")";

        for (PickTaskItem item : task.getItems()) {
            if (!item.isPicked()) {
                item.setPicked(true);
                productService.decreaseStock(item.getProduct().getId(), item.getQuantity(), workerInfo, task.getId());
            }
        }

        PickTask savedTask = pickTaskRepository.save(task);
        Map<String, Object> payload = new HashMap<>();
        payload.put("type", "TASK_COMPLETED");
        payload.put("message", "Görev " + savedTask.getTaskCode() + " tamamlandı!");
        payload.put("boxId", savedTask.getId());
        payload.put("taskId", savedTask.getId());
        payload.put("workerId", savedTask.getAssignedWorker() != null ? savedTask.getAssignedWorker().getId() : "Bilinmiyor");
        messagingTemplate.convertAndSend("/topic/manager/tasks", payload);

        log.info("Görev başarıyla tamamlandı ve stoklar düşüldü. Görev Kodu: {}", savedTask.getTaskCode());

        return pickTaskMapper.toResponseDto(savedTask);
    }

    @Transactional(readOnly = true)
    public List<PickTask> getCompletedTasksForWorker(Worker worker) {
        return pickTaskRepository.findByAssignedWorkerAndStatusAndIsDeletedFalse(worker, TaskStatus.COMPLETED);
    }

    @Transactional
    public PickTaskResponseDto pickTaskItem(Long taskId, Long productId, Worker actor) {
        PickTask task = pickTaskRepository.findById(taskId)
                .orElseThrow(() -> new RuntimeException("Görev bulunamadı!"));

        ensureWorkerCanOperate(task, actor);
        if (task.getIsDeleted() || task.getStatus() == TaskStatus.CANCELLED || task.getStatus() == TaskStatus.COMPLETED) {
            throw new IllegalStateException("İptal edilen veya tamamlanan görevden ürün toplanamaz.");
        }

        PickTaskItem itemToPick = task.getItems().stream()
                .filter(item -> item.getProduct().getId().equals(productId))
                .findFirst()
                .orElseThrow(() -> new RuntimeException("Ürün bulunamadı!"));

        if (itemToPick.isPicked()) {
            return pickTaskMapper.toResponseDto(task);
        }

        itemToPick.setPicked(true);
        pickTaskItemRepository.save(itemToPick);

        String workerInfo = actor.getFirstName() + " " + actor.getLastName() + " (" + actor.getRole().name() + ")";
        productService.decreaseStock(productId, itemToPick.getQuantity(), workerInfo, task.getId());

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
        payload.put("type", "ITEM_PICKED");
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
                .orElseThrow(() -> new RuntimeException("Görev bulunamadı!"));
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new RuntimeException("Personel bulunamadı!"));

        task.setAssignedWorker(worker);
        PickTask savedTask = pickTaskRepository.save(task);
        log.info("Görev (ID: {}) manuel olarak Personele (ID: {}) atandı.", taskId, workerId);

        return pickTaskMapper.toResponseDto(savedTask);
    }

    @Transactional
    public PickTaskResponseDto addItemToTask(Long taskId, PickTaskItemRequestDto itemDto) {
        PickTask task = pickTaskRepository.findById(taskId)
                .orElseThrow(() -> new RuntimeException("Görev bulunamadı!"));

        if (task.getStatus() == TaskStatus.COMPLETED) {
            throw new RuntimeException("Tamamlanmış görevlere ürün eklenemiyor!");
        }

        Product product = productRepository.findById(itemDto.getProductId())
                .orElseThrow(() -> new RuntimeException("Ürün bulunamadı!"));

        PickTaskItem newItem = new PickTaskItem();
        newItem.setProduct(product);
        newItem.setQuantity(itemDto.getQuantity());
        newItem.setPicked(false);

        task.addItem(newItem);
        PickTask savedTask = pickTaskRepository.save(task);

        Map<String, Object> payload = new HashMap<>();
        payload.put("type", "TASK_UPDATED");
        payload.put("message", "Görev içeriği güncellendi");
        payload.put("taskId", savedTask.getId());
        messagingTemplate.convertAndSend("/topic/manager/tasks", payload);

        log.info("Görev (ID: {}) için yeni ürün eklendi. Ürün ID: {}", taskId, itemDto.getProductId());

        return pickTaskMapper.toResponseDto(savedTask);
    }

    @Transactional(readOnly = true)
    public List<PickTask> getDeletedTasks() {
        return pickTaskRepository.findByIsDeletedTrueOrderByUpdatedAtDesc();
    }

    @Transactional(readOnly = true)
    public List<PickTask> getDeletedTasksForWorker(Worker worker) {
        return pickTaskRepository.findByAssignedWorkerAndIsDeletedTrueOrderByUpdatedAtDesc(worker);
    }

    @Transactional
    public void deleteTask(Long id, String reason, String cancelledBy) {
        PickTask task = pickTaskRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Görev bulunamadı!"));

        if (task.getStatus() == TaskStatus.COMPLETED) {
            throw new RuntimeException("Tamamlanmış görev silinemez/iptal edilemez!");
        }

        String workerInfo = cancelledBy + " (İptal Eden)";

        for (PickTaskItem item : task.getItems()) {
            if (item.isPicked()) {
                productService.increaseStock(item.getProduct().getId(), item.getQuantity(), workerInfo, id);
                item.setPicked(false);
            }
        }

        task.setStatus(TaskStatus.CANCELLED);
        task.setCancelReason(reason);
        task.setCancelledBy(cancelledBy);
        task.setIsDeleted(true);

        pickTaskRepository.save(task);

        Map<String, Object> payload = new HashMap<>();
        payload.put("type", "TASK_DELETED");
        payload.put("message", "Görev iptal edilerek silindi.");
        payload.put("taskId", id);
        messagingTemplate.convertAndSend("/topic/manager/tasks", payload);

        log.info("Görev silindi/iptal edildi. Stoklar iade edildi. Kodu: {}", task.getTaskCode());
    }

    @Transactional
    public PickTaskResponseDto removeItemFromTask(Long taskId, Long productId, String reason, String cancelledBy) {
        PickTask task = pickTaskRepository.findById(taskId)
                .orElseThrow(() -> new RuntimeException("Görev bulunamadı!"));

        if (task.getStatus() == TaskStatus.COMPLETED) {
            throw new RuntimeException("Tamamlanmış görevden ürün çıkarılamaz!");
        }

        PickTaskItem itemToRemove = task.getItems().stream()
                .filter(item -> item.getProduct().getId().equals(productId))
                .findFirst()
                .orElseThrow(() -> new RuntimeException("Görevde bu ürün bulunamadı!"));

        String workerInfo = cancelledBy + " (İptal Eden)";

        if (itemToRemove.isPicked()) {
            productService.increaseStock(productId, itemToRemove.getQuantity(), workerInfo, taskId);
            itemToRemove.setPicked(false);
        }

        if (task.getItems().size() == 1) {
            task.setStatus(TaskStatus.CANCELLED);
            task.setCancelReason("Görevdeki son ürün çıkarıldığı için görev iptal edildi. (Neden: " + reason + ")");
            task.setCancelledBy(cancelledBy);
            PickTask savedTask = pickTaskRepository.save(task);

            Map<String, Object> payload = new HashMap<>();
            payload.put("type", "TASK_DELETED");
            payload.put("message", "Görev tamamen iptal edildi.");
            payload.put("taskId", taskId);
            messagingTemplate.convertAndSend("/topic/manager/tasks", payload);

            return pickTaskMapper.toResponseDto(savedTask);
        }

        task.removeItem(itemToRemove);

        PickTask cancelledRecord = new PickTask();
        cancelledRecord.setTaskCode(task.getTaskCode() + "-REMOVED");
        cancelledRecord.setStatus(TaskStatus.CANCELLED);
        cancelledRecord.setCancelReason("[URUN_CIKARILDI-" + taskId + "] " + reason);
        cancelledRecord.setCancelledBy(cancelledBy);

        PickTaskItem cancelledItem = new PickTaskItem();
        cancelledItem.setProduct(itemToRemove.getProduct());
        cancelledItem.setQuantity(itemToRemove.getQuantity());
        cancelledItem.setPicked(false);
        cancelledRecord.addItem(cancelledItem);

        pickTaskRepository.save(cancelledRecord);
        PickTask savedTask = pickTaskRepository.save(task);

        Map<String, Object> payload = new HashMap<>();
        payload.put("type", "TASK_DELETED");
        payload.put("message", "Görevden ürün çıkarıldı, iptal listesine eklendi.");
        payload.put("taskId", taskId);
        messagingTemplate.convertAndSend("/topic/manager/tasks", payload);

        return pickTaskMapper.toResponseDto(savedTask);
    }

    private void ensureWorkerCanOperate(PickTask task, Worker actor) {
        if (actor.getRole() == Role.ADMIN) return;
        if (task.getAssignedWorker() == null || !task.getAssignedWorker().getId().equals(actor.getId())) {
            throw new AccessDeniedException("Bu görev için işlem yetkiniz yok.");
        }
    }
}