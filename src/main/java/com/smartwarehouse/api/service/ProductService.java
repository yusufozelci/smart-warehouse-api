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

import java.util.List;

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
        Shelf shelf = shelfRepository.findById(request.getShelfId())
                .orElseThrow(() -> new RuntimeException("Belirtilen raf bulunamadı!"));

        String sku = "SKU-" + java.util.UUID.randomUUID().toString().substring(0, 8).toUpperCase();

        Product product = productMapper.toEntity(request, shelf);
        product.setSku(sku);
        product.setStockQuantity(request.getStockQuantity());

        return productMapper.toResponseDto(productRepository.save(product));
    }

    public ProductResponseDto getProduct(Long id) {
        Product product = productRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Ürün bulunamadı!"));
        return productMapper.toResponseDto(product);
    }

    @Transactional
    public ProductResponseDto updateProduct(Long id, ProductRequestDto request) {
        Product product = productRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Ürün bulunamadı!"));

        product.setName(request.getName());
        product.setStockQuantity(request.getStockQuantity());
        return productMapper.toResponseDto(productRepository.save(product));
    }

    @Transactional
    public void deleteProduct(Long id) {
        if (!productRepository.existsById(id)) {
            throw new RuntimeException("Silinecek ürün bulunamadı!");
        }
        productRepository.deleteById(id);
    }
    @Transactional
    public List<ProductResponseDto> getProductsByShelf(Long shelfId) {
        Shelf shelf = shelfRepository.findById(shelfId)
                .orElseThrow(() -> new RuntimeException("Raf bulunamadı!"));

        return shelf.getProducts().stream()
                .map(productMapper::toResponseDto)
                .toList();
    }
    @Transactional
    public String getShelfLocation(Long shelfId) {
        Shelf shelf = shelfRepository.findById(shelfId)
                .orElseThrow(() -> new RuntimeException("Raf bulunamadı!"));
        return "X: " + shelf.getCoordinateX() + ", Y: " + shelf.getCoordinateY();
    }
}