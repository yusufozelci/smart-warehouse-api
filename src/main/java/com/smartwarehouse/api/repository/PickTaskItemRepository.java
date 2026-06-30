package com.smartwarehouse.api.repository;

import com.smartwarehouse.api.entity.PickTaskItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PickTaskItemRepository extends JpaRepository<PickTaskItem, Long> {
}