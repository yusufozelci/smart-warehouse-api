package com.smartwarehouse.api.controller;

import com.smartwarehouse.api.dto.ProductRequestDto;
import com.smartwarehouse.api.dto.ProductResponseDto;
import com.smartwarehouse.api.entity.Product;
import com.smartwarehouse.api.entity.Shelf;
import com.smartwarehouse.api.mapper.ProductMapper;
import com.smartwarehouse.api.repository.ProductRepository;
import com.smartwarehouse.api.repository.ShelfRepository;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/v1/products")
public class ProductController {

    private final ProductRepository productRepository;
    private final ShelfRepository shelfRepository;
    private final ProductMapper productMapper;

    public ProductController(ProductRepository productRepository, ShelfRepository shelfRepository, ProductMapper productMapper) {
        this.productRepository = productRepository;
        this.shelfRepository = shelfRepository;
        this.productMapper = productMapper;
    }

    @PostMapping
    public ResponseEntity<ProductResponseDto> createProduct(@RequestBody ProductRequestDto request) {

        Shelf shelf = null;
        if (request.getShelfId() != null) {
            shelf = shelfRepository.findWithProductsById(request.getShelfId())
                    .orElseThrow(() -> new RuntimeException("Raf bulunamadı. ID: " + request.getShelfId()));
        }

        Product newProduct = productMapper.toEntity(request, shelf);

        if (newProduct.getSku() == null || newProduct.getSku().isEmpty()) {
            newProduct.setSku(UUID.randomUUID().toString().substring(0, 8).toUpperCase());
        }
        if (newProduct.getQrCodeData() == null || newProduct.getQrCodeData().isEmpty()) {
            newProduct.setQrCodeData("QR-" + UUID.randomUUID().toString().substring(0, 8));
        }

        Product savedProduct = productRepository.save(newProduct);
        return new ResponseEntity<>(productMapper.toResponseDto(savedProduct), HttpStatus.CREATED);
    }
    @GetMapping
    public ResponseEntity<List<ProductResponseDto>> getAllProducts() {
        List<ProductResponseDto> products = productRepository.findAll()
                .stream()
                .map(productMapper::toResponseDto)
                .collect(Collectors.toList());
        return ResponseEntity.ok(products);
    }

    @GetMapping("/{sku}")
    public ResponseEntity<ProductResponseDto> getProductBySku(@PathVariable String sku) {
        return productRepository.findBySku(sku)
                .map(product -> ResponseEntity.ok(productMapper.toResponseDto(product))) // Senin mapper metodun
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteProduct(@PathVariable Long id) {
        if (!productRepository.existsById(id)) {
            return ResponseEntity.notFound().build();
        }
        productRepository.deleteById(id);
        return ResponseEntity.noContent().build();
    }
}