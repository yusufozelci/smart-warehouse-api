package com.smartwarehouse.api.repository;

import com.smartwarehouse.api.entity.SystemErrorLog;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface SystemErrorLogRepository extends JpaRepository<SystemErrorLog, Long> {
    List<SystemErrorLog> findAllByOrderByTimestampDesc();
}