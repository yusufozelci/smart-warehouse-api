package com.smartwarehouse.api.repository;

import com.smartwarehouse.api.entity.Product;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ProductRepository extends JpaRepository<Product, Long> {
    @Query("SELECT p FROM Product p JOIN FETCH p.shelf")
    List<Product> findAllWithShelf();
    Optional<Product> findBySku(String sku);
}