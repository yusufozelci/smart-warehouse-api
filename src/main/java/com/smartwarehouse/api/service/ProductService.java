package com.smartwarehouse.api.service;

import com.smartwarehouse.api.dto.ProductRequestDto;
import com.smartwarehouse.api.dto.ProductResponseDto;
import com.smartwarehouse.api.entity.Product;
import com.smartwarehouse.api.entity.Shelf;
import com.smartwarehouse.api.mapper.ProductMapper;
import com.smartwarehouse.api.repository.ProductRepository;
import com.smartwarehouse.api.repository.ShelfRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.hibernate.Hibernate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class ProductService {

    private final ProductRepository productRepository;
    private final ShelfRepository shelfRepository;
    private final ProductMapper productMapper;

    @Transactional
    public ProductResponseDto addProduct(ProductRequestDto request) {
        if (request.getShelfId() == null) {
            log.warn("Ürün ekleme hatası: Raf ID boş gönderildi.");
            throw new RuntimeException("Raf ID boş bırakılamaz! Lütfen geçerli bir Raf ID girin.");
        }

        Shelf shelf = shelfRepository.findById(request.getShelfId())
                .orElseThrow(() -> {
                    log.error("Ürün ekleme hatası: Belirtilen raf bulunamadı! ID: {}", request.getShelfId());
                    return new RuntimeException("Belirtilen raf bulunamadı! ID: " + request.getShelfId());
                });

        Product product = productMapper.toEntity(request, shelf);
        product.setSku("SKU-" + java.util.UUID.randomUUID().toString().substring(0, 8).toUpperCase());

        Product savedProduct = productRepository.save(product);
        log.info("Ürün başarıyla eklendi. SKU: {}", savedProduct.getSku());

        return productMapper.toResponseDto(savedProduct);
    }

    @Transactional
    public ProductResponseDto decreaseStock(Long id, int amount) {
        Product product = productRepository.findById(id)
                .orElseThrow(() -> {
                    log.error("Stok düşürme hatası: Ürün bulunamadı! ID: {}", id);
                    return new RuntimeException("Ürün bulunamadı!");
                });

        if (amount <= 0) {
            log.warn("Geçersiz stok düşürme denemesi. Miktar: {}", amount);
            throw new RuntimeException("Düşülecek miktar 0'dan büyük olmalıdır!");
        }

        if (product.getStockQuantity() < amount) {
            log.warn("Yetersiz stok hatası! Ürün ID: {}, Mevcut: {}, İstenen: {}", id, product.getStockQuantity(), amount);
            throw new RuntimeException("Yetersiz stok! Mevcut: " + product.getStockQuantity());
        }

        product.setStockQuantity(product.getStockQuantity() - amount);
        log.info("Stok başarıyla düşürüldü. Ürün ID: {}, Kalan Stok: {}", id, product.getStockQuantity());

        return productMapper.toResponseDto(productRepository.save(product));
    }

    @Transactional
    public void deleteProduct(Long id) {
        try {
            productRepository.deleteById(id);
            log.info("Ürün başarıyla silindi. ID: {}", id);
        } catch (Exception e) {
            log.error("Ürün silinirken hata oluştu! ID: {}", id, e);
            throw new RuntimeException("Ürün silinirken hata oluştu!");
        }
    }

    public List<ProductResponseDto> getAllProducts() {
        return productRepository.findAllWithShelf().stream()
                .map(productMapper::toResponseDto)
                .toList();
    }

    @Transactional
    public ProductResponseDto updateProduct(Long id, ProductRequestDto request) {
        Product product = productRepository.findById(id)
                .orElseThrow(() -> {
                    log.error("Ürün güncelleme hatası: Ürün bulunamadı! ID: {}", id);
                    return new RuntimeException("Ürün bulunamadı! ID: " + id);
                });

        if (request.getShelfId() != null) {
            Shelf shelf = shelfRepository.findById(request.getShelfId())
                    .orElseThrow(() -> {
                        log.error("Ürün güncelleme hatası: Belirtilen raf bulunamadı! ID: {}", request.getShelfId());
                        return new RuntimeException("Belirtilen raf bulunamadı! ID: " + request.getShelfId());
                    });
            product.setShelf(shelf);
        }

        if (request.getName() != null && !request.getName().isEmpty()) {
            product.setName(request.getName());
        }

        log.info("Ürün başarıyla güncellendi. ID: {}", id);
        return productMapper.toResponseDto(productRepository.save(product));
    }

    @Transactional
    public Product increaseStock(Long id, int amount) {
        Product product = productRepository.findById(id)
                .orElseThrow(() -> {
                    log.error("Stok artırma hatası: Ürün bulunamadı! ID: {}", id);
                    return new RuntimeException("Ürün bulunamadı ID: " + id);
                });

        product.setStockQuantity(product.getStockQuantity() + amount);
        Product savedProduct = productRepository.save(product);

        if (savedProduct.getShelf() != null) {
            Hibernate.initialize(savedProduct.getShelf());
        }

        log.info("Stok başarıyla artırıldı. Ürün ID: {}, Yeni Stok: {}", id, savedProduct.getStockQuantity());
        return savedProduct;
    }
}