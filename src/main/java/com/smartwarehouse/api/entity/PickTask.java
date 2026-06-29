package com.smartwarehouse.api.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.util.List;

@EqualsAndHashCode(callSuper = true)
@Entity
@Table(name = "pick_tasks")
@Data
public class PickTask extends BaseEntity {

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TaskStatus status;

    @ManyToOne
    @JoinColumn(name = "assigned_worker_id")
    private Worker assignedWorker;

    @OneToMany(mappedBy = "pickTask", cascade = CascadeType.ALL)
    private List<PickTaskItem> items;
}
