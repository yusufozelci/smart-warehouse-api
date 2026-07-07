package com.smartwarehouse.api.controller;

import com.smartwarehouse.api.dto.WorkerLocationDto;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.SendTo;
import org.springframework.stereotype.Controller;

@Controller
public class LiveTrackingController {

    @MessageMapping("/worker.location")
    @SendTo("/topic/live-tracking")
    public WorkerLocationDto updateLocation(WorkerLocationDto location) {

        System.out.println("CANLI KONUM GÜNCELLEMESİ: Personel " + location.getWorkerId() +
                " şu an Raf " + location.getCurrentShelfId() + " konumunda.");

        return location;
    }
}