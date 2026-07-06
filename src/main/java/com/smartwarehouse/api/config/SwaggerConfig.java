package com.smartwarehouse.api.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class SwaggerConfig {

    @Bean
    public OpenAPI smartWarehouseOpenAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("Smart Warehouse API")
                        .description("Akıllı Depo Yönetim Sistemi - Lojistik ve Rota Rptimizasyonu REST API Dokümantasyonu")
                        .version("v1.0.0"));
    }
}