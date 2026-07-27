package com.smartwarehouse.api.controller;

import com.smartwarehouse.api.dto.ProductRequestDto;
import com.smartwarehouse.api.dto.ProductResponseDto;
import com.smartwarehouse.api.entity.Product;
import com.smartwarehouse.api.entity.Worker;
import com.smartwarehouse.api.service.ProductService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

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
    public ResponseEntity<ProductResponseDto> decreaseStock(@PathVariable Long id, @RequestParam int amount, @AuthenticationPrincipal Worker actor) {
        String workerInfo = (actor != null) ? actor.getFirstName() + " " + actor.getLastName() + " (" + actor.getRole().name() + ")" : "Sistem/Admin";
        return ResponseEntity.ok(productService.decreaseStock(id, amount, workerInfo, null));
    }

    @PutMapping("/{id}/increase")
    public ResponseEntity<Product> increaseStock(@PathVariable Long id, @RequestParam int amount, @AuthenticationPrincipal Worker actor) {
        String workerInfo = (actor != null) ? actor.getFirstName() + " " + actor.getLastName() + " (" + actor.getRole().name() + ")" : "Sistem/Admin";
        return ResponseEntity.ok(productService.increaseStock(id, amount, workerInfo, null));
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
}