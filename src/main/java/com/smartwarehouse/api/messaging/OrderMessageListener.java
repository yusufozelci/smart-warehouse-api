package com.smartwarehouse.api.messaging;

import com.smartwarehouse.api.config.RabbitMQConfig;
import com.smartwarehouse.api.dto.OrderEventDto;
import com.smartwarehouse.api.service.PickTaskService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class OrderMessageListener {

    private final PickTaskService pickTaskService;

    @RabbitListener(queues = RabbitMQConfig.ORDER_QUEUE)
    public void consumeOrderMessage(OrderEventDto orderEvent) {
        log.info("Sipariş işleme kuyruğundan mesaj alındı. Sipariş No: {}", orderEvent.getOrderId());

        try {
            pickTaskService.createTaskFromOrder(orderEvent);
            log.info("Sipariş, görev (PickTask) tablosuna başarıyla kaydedildi.");

        } catch (Exception e) {
            log.error("RabbitMQ mesajı işlenirken hata oluştu! Hata: {}", e.getMessage());
        }
    }
}