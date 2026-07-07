package com.smartwarehouse.api.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.util.ArrayList;
import java.util.List;

@EqualsAndHashCode(callSuper = true, exclude = "items")
@Entity
@Table(name = "pick_tasks")
@Data
public class PickTask extends BaseEntity {

    @Column(nullable = false)
    private String taskCode;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TaskStatus status;

    @ManyToOne
    @JoinColumn(name = "worker_id")
    private Worker assignedWorker;

    @OneToMany(mappedBy = "pickTask", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<PickTaskItem> items = new ArrayList<>();

    public void addItem(PickTaskItem item) {
        items.add(item);
        item.setPickTask(this);
    }

    public void removeItem(PickTaskItem item) {
        items.remove(item);
        item.setPickTask(null);
    }
}
