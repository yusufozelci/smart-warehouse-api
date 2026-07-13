package com.smartwarehouse.api.repository;

import com.smartwarehouse.api.entity.Worker;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface WorkerRepository extends JpaRepository<Worker, Long> {
    Optional<Worker> findByEmail(String email);
    List<Worker> findAllByIsDeletedFalse();
}