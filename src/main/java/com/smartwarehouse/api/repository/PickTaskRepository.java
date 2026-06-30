package com.smartwarehouse.api.repository;

import com.smartwarehouse.api.entity.PickTask;
import com.smartwarehouse.api.entity.TaskStatus;
import com.smartwarehouse.api.entity.Worker;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface PickTaskRepository extends JpaRepository<PickTask, Long> {
    List<PickTask> findByAssignedWorkerAndStatus(Worker worker, TaskStatus status);
}