package com.smartwarehouse.api.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;
import java.util.List;

@EqualsAndHashCode(callSuper = true)
@Entity
@Table(name = "shelves")
@Data
@NoArgsConstructor
@AllArgsConstructor

public class Shelf extends BaseEntity{

    @Column(unique = true, nullable = false)
    private String shelfCode;

    @Column(nullable = false)
    private Integer coordinateX;

    @Column(nullable = false)
    private Integer coordinateY;

    @OneToMany(mappedBy = "shelf")
    private List<Product> products;
}
