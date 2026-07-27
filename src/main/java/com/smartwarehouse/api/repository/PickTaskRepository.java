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
    long countByAssignedWorkerIdAndStatusAndIsDeletedFalse(Long workerId, TaskStatus status);
    long countByAssignedWorkerIdAndIsDeletedFalse(Long workerId);
    @Query("SELECT COALESCE(SUM(i.quantity), 0) FROM PickTask t JOIN t.items i WHERE t.assignedWorker.id = :workerId AND i.isPicked = true AND t.isDeleted = false")
    long sumPickedItemsByWorkerId(@org.springframework.data.repository.query.Param("workerId") Long workerId);

    @Query("SELECT t FROM PickTask t WHERE t.assignedWorker.id = :workerId AND t.status = 'COMPLETED' AND t.isDeleted = false AND t.updatedAt >= :startDate")
    List<PickTask> findCompletedTasksSince(@org.springframework.data.repository.query.Param("workerId") Long workerId, @org.springframework.data.repository.query.Param("startDate") java.time.LocalDateTime startDate);
}