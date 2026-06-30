package com.smartwarehouse.api.repository;

import com.smartwarehouse.api.entity.Shelf;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ShelfRepository extends JpaRepository<Shelf, Long> {
    Optional<Shelf> findByShelfCode(String shelfCode);
}