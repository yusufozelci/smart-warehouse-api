package com.smartwarehouse.api.service;

import com.smartwarehouse.api.dto.PickTaskItemRequestDto;
import com.smartwarehouse.api.dto.PickTaskRequestDto;
import com.smartwarehouse.api.dto.PickTaskResponseDto;
import com.smartwarehouse.api.entity.*;
import com.smartwarehouse.api.mapper.PickTaskMapper;
import com.smartwarehouse.api.repository.PickTaskRepository;
import com.smartwarehouse.api.repository.ProductRepository;
import com.smartwarehouse.api.repository.WorkerRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

@Service
public class PickTaskService {

    private final PickTaskRepository pickTaskRepository;
    private final ProductRepository productRepository;
    private final WorkerRepository workerRepository;
    private final PickTaskMapper pickTaskMapper;

    public PickTaskService(PickTaskRepository pickTaskRepository, ProductRepository productRepository, WorkerRepository workerRepository, PickTaskMapper pickTaskMapper) {
        this.pickTaskRepository = pickTaskRepository;
        this.productRepository = productRepository;
        this.workerRepository = workerRepository;
        this.pickTaskMapper = pickTaskMapper;
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

        List<PickTaskItem> items = new ArrayList<>();

        for (PickTaskItemRequestDto itemDto : request.getItems()) {
            Product product = productRepository.findById(itemDto.getProductId())
                    .orElseThrow(() -> new RuntimeException("Ürün bulunamadı ID: " + itemDto.getProductId()));

            if (product.getStockQuantity() < itemDto.getQuantity()) {
                throw new RuntimeException("Yetersiz stok! Ürün: " + product.getName() + " Mevcut: " + product.getStockQuantity());
            }

            PickTaskItem item = new PickTaskItem();
            item.setPickTask(task);
            item.setProduct(product);
            item.setQuantity(itemDto.getQuantity());
            item.setPicked(false);

            items.add(item);
        }

        task.setItems(items);
        PickTask savedTask = pickTaskRepository.save(task);

        return pickTaskMapper.toResponseDto(savedTask);
    }
}