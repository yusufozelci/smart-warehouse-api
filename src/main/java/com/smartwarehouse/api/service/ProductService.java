package com.smartwarehouse.api.service;

import com.smartwarehouse.api.dto.ProductRequestDto;
import com.smartwarehouse.api.dto.ProductResponseDto;
import com.smartwarehouse.api.entity.Product;
import com.smartwarehouse.api.entity.Shelf;
import com.smartwarehouse.api.mapper.ProductMapper;
import com.smartwarehouse.api.repository.ProductRepository;
import com.smartwarehouse.api.repository.ShelfRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ProductService {

    private final ProductRepository productRepository;
    private final ShelfRepository shelfRepository;
    private final ProductMapper productMapper;

    @Transactional
    public ProductResponseDto addProduct(ProductRequestDto request) {
        if (request.getShelfId() == null) {
            throw new RuntimeException("Raf ID boş bırakılamaz! Lütfen geçerli bir Raf ID girin.");
        }
        Shelf shelf = shelfRepository.findById(request.getShelfId())
                .orElseThrow(() -> new RuntimeException("Belirtilen raf bulunamadı! ID: " + request.getShelfId()));

        Product product = productMapper.toEntity(request, shelf);
        product.setSku("SKU-" + java.util.UUID.randomUUID().toString().substring(0, 8).toUpperCase());
        return productMapper.toResponseDto(productRepository.save(product));
    }
    @Transactional
    public ProductResponseDto decreaseStock(Long id, int amount) {
        Product product = productRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Ürün bulunamadı!"));

        if (amount <= 0) {
            throw new RuntimeException("Düşülecek miktar 0'dan büyük olmalıdır!");
        }

        if (product.getStockQuantity() < amount) {
            throw new RuntimeException("Yetersiz stok! Mevcut: " + product.getStockQuantity());
        }

        product.setStockQuantity(product.getStockQuantity() - amount);
        return productMapper.toResponseDto(productRepository.save(product));
    }

    @Transactional
    public void deleteProduct(Long id) {
        productRepository.deleteById(id);
    }

    public List<ProductResponseDto> getAllProducts() {
        return productRepository.findAllWithShelf().stream()
                .map(productMapper::toResponseDto)
                .toList();
    }

    @Transactional
    public ProductResponseDto updateProduct(Long id, ProductRequestDto request) {
        Product product = productRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Ürün bulunamadı! ID: " + id));
        if (request.getShelfId() != null) {
            Shelf shelf = shelfRepository.findById(request.getShelfId())
                    .orElseThrow(() -> new RuntimeException("Belirtilen raf bulunamadı! ID: " + request.getShelfId()));
            product.setShelf(shelf);
        }
        if (request.getName() != null && !request.getName().isEmpty()) {
            product.setName(request.getName());
        }

        return productMapper.toResponseDto(productRepository.save(product));
    }
}