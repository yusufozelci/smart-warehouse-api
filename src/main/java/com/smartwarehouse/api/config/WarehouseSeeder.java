package com.smartwarehouse.api.config;

import com.smartwarehouse.api.entity.Shelf;
import com.smartwarehouse.api.repository.ShelfRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;

@Component
public class WarehouseSeeder implements CommandLineRunner {

    private final ShelfRepository shelfRepository;

    public WarehouseSeeder(ShelfRepository shelfRepository) {
        this.shelfRepository = shelfRepository;
    }

    @Override
    public void run(String... args) throws Exception {
        if (shelfRepository.count() == 0) {
            System.out.println("--- 10/10 ENTERPRISE DEPO İNŞA EDİLİYOR ---");
            List<Shelf> initialShelves = new ArrayList<>();

            int shelfWidth = 150;
            int shelfHeight = 100;
            int aisleGap = 250;

            for (int f = 1; f <= 3; f++) {
                int shelfCounter = 1;

                for (int row = 0; row < 6; row++) {
                    for (int col = 0; col < 6; col++) {
                        String code = "F" + f + "-A" + String.format("%02d", shelfCounter++);

                        int x = 80 + (col * shelfWidth);
                        if (col >= 3) {
                            x += aisleGap;
                        }

                        int y = 80 + (row * shelfHeight);
                        if (row >= 3) {
                            y += aisleGap;
                        }

                        initialShelves.add(createShelf(code, x, y, f));
                    }
                }
            }
            shelfRepository.saveAll(initialShelves);
            System.out.println("--- DEPO BAŞARIYLA OLUŞTURULDU ---");
        }
    }

    private Shelf createShelf(String code, int x, int y, int floor) {
        Shelf shelf = new Shelf();
        shelf.setShelfCode(code);
        shelf.setCoordinateX(x);
        shelf.setCoordinateY(y);
        shelf.setFloor(floor);
        return shelf;
    }
}