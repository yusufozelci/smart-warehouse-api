package com.smartwarehouse.api.repository;

import com.smartwarehouse.api.entity.PickTask;
import com.smartwarehouse.api.entity.TaskStatus;
import com.smartwarehouse.api.entity.Worker;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import org.springframework.lang.NonNull;
import java.util.List;

@Repository
public interface PickTaskRepository extends JpaRepository<PickTask, Long> {
    @EntityGraph(attributePaths = {"items", "items.product", "items.product.shelf", "assignedWorker"})
    List<PickTask> findByAssignedWorkerAndStatusInAndIsDeletedFalse(Worker worker, List<TaskStatus> statuses);

    @EntityGraph(attributePaths = {"items", "items.product", "items.product.shelf", "assignedWorker"})
    List<PickTask> findByAssignedWorkerAndStatusAndIsDeletedFalse(Worker worker, TaskStatus status);
    long countByStatus(TaskStatus status);

    @EntityGraph(attributePaths = {"items", "items.product", "items.product.shelf", "assignedWorker"})
    List<PickTask> findByIsDeletedTrueOrderByUpdatedAtDesc();

    @EntityGraph(attributePaths = {"items", "items.product", "items.product.shelf", "assignedWorker"})
    List<PickTask> findByAssignedWorkerAndIsDeletedTrueOrderByUpdatedAtDesc(Worker worker);

    @EntityGraph(attributePaths = {"items", "items.product", "items.product.shelf", "assignedWorker"})
    List<PickTask> findAllByOrderByCreatedAtDesc();
}