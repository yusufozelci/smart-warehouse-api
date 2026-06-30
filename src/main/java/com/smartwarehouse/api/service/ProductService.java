package com.smartwarehouse.api.service;

import com.smartwarehouse.api.dto.ProductRequestDto;
import com.smartwarehouse.api.dto.ProductResponseDto;
import com.smartwarehouse.api.entity.Product;
import com.smartwarehouse.api.entity.Shelf;
import com.smartwarehouse.api.mapper.ProductMapper;
import com.smartwarehouse.api.repository.ProductRepository;
import com.smartwarehouse.api.repository.ShelfRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ProductService {

    private final ProductRepository productRepository;
    private final ShelfRepository shelfRepository;
    private final ProductMapper productMapper;

    public ProductService(ProductRepository productRepository, ShelfRepository shelfRepository, ProductMapper productMapper) {
        this.productRepository = productRepository;
        this.shelfRepository = shelfRepository;
        this.productMapper = productMapper;
    }

    @Transactional
    public ProductResponseDto addProduct(ProductRequestDto request) {
        if (productRepository.findBySku(request.getSku()).isPresent()) {
            throw new RuntimeException("Bu SKU koduna sahip bir ürün zaten mevcut!");
        }

        Shelf shelf = shelfRepository.findById(request.getShelfId())
                .orElseThrow(() -> new RuntimeException("Belirtilen raf bulunamadı!"));

        if (request.getStockQuantity() < 0) {
            throw new RuntimeException("Stok miktarı sıfırdan küçük olamaz!");
        }

        Product product = productMapper.toEntity(request, shelf);

        Product savedProduct = productRepository.save(product);

        return productMapper.toResponseDto(savedProduct);
    }
}