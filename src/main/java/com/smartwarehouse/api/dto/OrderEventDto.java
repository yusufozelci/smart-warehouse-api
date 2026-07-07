package com.smartwarehouse.api.dto;

import lombok.Data;
import java.io.Serializable;
import java.util.List;

@Data
public class OrderEventDto implements Serializable {
    private String orderId;
    private String companyName;
    private List<Long> productIds;
}