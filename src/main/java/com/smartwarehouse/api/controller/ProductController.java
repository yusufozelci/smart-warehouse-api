package com.smartwarehouse.api.controller;

import com.smartwarehouse.api.dto.ProductRequestDto;
import com.smartwarehouse.api.dto.ProductResponseDto;
import com.smartwarehouse.api.entity.Product;
import com.smartwarehouse.api.entity.Shelf;
import com.smartwarehouse.api.mapper.ProductMapper;
import com.smartwarehouse.api.repository.ProductRepository;
import com.smartwarehouse.api.repository.ShelfRepository;
import com.smartwarehouse.api.service.ProductService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/v1/products")
@RequiredArgsConstructor
public class ProductController {

    private final ProductService productService;

    @PostMapping
    public ResponseEntity<ProductResponseDto> createProduct(@RequestBody ProductRequestDto request) {
        return ResponseEntity.ok(productService.addProduct(request));
    }

    @GetMapping
    public ResponseEntity<List<ProductResponseDto>> getAllProducts() {
        return ResponseEntity.ok(productService.getAllProducts());
    }

    @PutMapping("/{id}/decrease")
    public ResponseEntity<?> decreaseStock(@PathVariable Long id, @RequestParam int amount) {
        try {
            return ResponseEntity.ok(productService.decreaseStock(id, amount));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteProduct(@PathVariable Long id) {
        productService.deleteProduct(id);
        return ResponseEntity.noContent().build();
    }

    @PutMapping("/{id}")
    public ResponseEntity<ProductResponseDto> updateProduct(@PathVariable Long id, @RequestBody ProductRequestDto request) {
        return ResponseEntity.ok(productService.updateProduct(id, request));
    }

    @PutMapping("/{id}/increase")
    public ResponseEntity<?> increaseStock(@PathVariable Long id, @RequestParam int amount) {
        try {
            Product updatedProduct = productService.increaseStock(id, amount);
            return ResponseEntity.ok(updatedProduct);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }
}