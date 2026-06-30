package com.smartwarehouse.api.mapper;

import com.smartwarehouse.api.dto.ProductRequestDto;
import com.smartwarehouse.api.dto.ProductResponseDto;
import com.smartwarehouse.api.entity.Product;
import com.smartwarehouse.api.entity.Shelf;
import org.springframework.stereotype.Component;

@Component
public class ProductMapper {

    public ProductResponseDto toResponseDto(Product product) {
        if (product == null) {
            return null;
        }

        ProductResponseDto dto = new ProductResponseDto();
        dto.setId(product.getId());
        dto.setName(product.getName());
        dto.setSku(product.getSku());
        dto.setStockQuantity(product.getStockQuantity());

        if (product.getShelf() != null) {
            dto.setShelfCode(product.getShelf().getShelfCode());
        }

        dto.setCreatedAt(product.getCreatedAt());
        return dto;
    }

    public Product toEntity(ProductRequestDto dto, Shelf shelf) {
        if (dto == null) {
            return null;
        }

        Product product = new Product();
        product.setName(dto.getName());
        product.setSku(dto.getSku());
        product.setStockQuantity(dto.getStockQuantity());
        product.setShelf(shelf);

        return product;
    }
}