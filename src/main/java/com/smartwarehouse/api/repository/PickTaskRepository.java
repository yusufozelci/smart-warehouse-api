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
    List<PickTask> findByAssignedWorkerAndStatusIn(Worker worker, List<TaskStatus> statuses);

    @EntityGraph(attributePaths = {"items", "items.product", "items.product.shelf", "assignedWorker"})
    List<PickTask> findByAssignedWorkerAndStatus(Worker worker, TaskStatus status);

    @EntityGraph(attributePaths = {"items", "items.product", "items.product.shelf"})
    @Query("SELECT p FROM PickTask p")
    List<PickTask> findByStatus(TaskStatus status);

    @NonNull
    @EntityGraph(attributePaths = {"items", "items.product", "items.product.shelf", "assignedWorker"})
    List<PickTask> findAll();

    long countByStatus(TaskStatus status);
}