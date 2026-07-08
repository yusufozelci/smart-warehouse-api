package com.smartwarehouse.api;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.amqp.RabbitAutoConfiguration;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

@SpringBootApplication(exclude = {RabbitAutoConfiguration.class})
@EnableJpaAuditing
@EnableCaching
public class WarehouseApiApplication {

	public static void main(String[] args) {
		SpringApplication.run(WarehouseApiApplication.class, args);
	}

}
