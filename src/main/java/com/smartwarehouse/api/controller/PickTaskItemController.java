package com.smartwarehouse.api.controller;

import com.smartwarehouse.api.entity.PickTaskItem;
import com.smartwarehouse.api.repository.PickTaskItemRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/task-items")
public class PickTaskItemController {

    private final PickTaskItemRepository pickTaskItemRepository;


    @PostMapping
    public ResponseEntity<PickTaskItem> addTaskItem(@RequestBody PickTaskItem taskItem) {
        PickTaskItem savedItem = pickTaskItemRepository.save(taskItem);
        return new ResponseEntity<>(savedItem, HttpStatus.CREATED);
    }

    @GetMapping("/task/{taskId}")
    public ResponseEntity<List<PickTaskItem>> getItemsByTaskId(@PathVariable Long taskId) {
        List<PickTaskItem> items = pickTaskItemRepository.findByPickTaskId(taskId);
        return ResponseEntity.ok(items);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteTaskItem(@PathVariable Long id) {
        if (!pickTaskItemRepository.existsById(id)) {
            return ResponseEntity.notFound().build();
        }
        pickTaskItemRepository.deleteById(id);
        return ResponseEntity.noContent().build();
    }
}