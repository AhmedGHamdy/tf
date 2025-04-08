resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_service_plan" "main" {
  name                = var.app_service_plan_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Windows"
  sku_name            = var.app_service_sku
  tags                = var.tags
}

resource "azurerm_windows_web_app" "main" {
  name                = var.app_service_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id
  
  site_config {
    application_stack {
      current_stack  = "dotnet"
      dotnet_version = "v6.0"
    }
    always_on        = true
    ftps_state       = "Disabled"
    http2_enabled    = true
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
    "ASPNETCORE_ENVIRONMENT"   = "Production"
  }

  tags = var.tags
}

resource "azurerm_api_management" "main" {
  name                = var.api_management_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  publisher_name      = var.api_management_publisher_name
  publisher_email     = var.api_management_publisher_email
  sku_name            = var.api_management_sku
  
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_api_management_product" "main" {
  product_id            = "api-product"
  api_management_name   = azurerm_api_management.main.name
  resource_group_name   = azurerm_resource_group.main.name
  display_name          = "API Product"
  subscription_required = true
  approval_required     = false
  published             = true
}

resource "azurerm_api_management_api" "main" {
  name                = "api"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  revision            = "1"
  display_name        = "API"
  path                = ""
  protocols           = ["https"]
  service_url         = "https://${azurerm_windows_web_app.main.default_hostname}"
}

resource "azurerm_api_management_product_api" "main" {
  product_id          = azurerm_api_management_product.main.product_id
  api_id              = azurerm_api_management_api.main.id
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_api_management_api_policy" "main" {
  api_name            = azurerm_api_management_api.main.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <rate-limit-by-key calls="300" renewal-period="60" counter-key="@(context.Request.IpAddress)" />
    <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized">
      <openid-config url="https://login.microsoftonline.com/common/.well-known/openid-configuration" />
      <required-claims>
        <claim name="aud" match="any">
          <value>api://${azurerm_api_management.main.name}</value>
        </claim>
      </required-claims>
    </validate-jwt>
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}

resource "azurerm_api_management_subscription" "main" {
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  product_id          = azurerm_api_management_product.main.id
  display_name        = "Default Subscription"
  state               = "active"
}

resource "azurerm_frontdoor_firewall_policy" "main" {
  name                = var.frontdoor_waf_name
  resource_group_name = azurerm_resource_group.main.name
  
  managed_rule {
    type    = "DefaultRuleSet"
    version = "1.0"
  }

  managed_rule {
    type    = "Microsoft_BotManagerRuleSet"
    version = "1.0"
  }

  tags = var.tags
}

resource "azurerm_frontdoor" "main" {
  name                = var.frontdoor_name
  resource_group_name = azurerm_resource_group.main.name
  
  routing_rule {
    name               = "api-routing-rule"
    accepted_protocols = ["Https"]
    patterns_to_match  = ["/*"]
    frontend_endpoints = ["api-frontend"]
    forwarding_configuration {
      forwarding_protocol = "HttpsOnly"
      backend_pool_name   = "api-backend-pool"
    }
  }

  backend_pool {
    name = "api-backend-pool"
    backend {
      host_header = azurerm_api_management.main.gateway_url
      address     = azurerm_api_management.main.gateway_url
      http_port   = 80
      https_port  = 443
    }
    
    load_balancing_name = "api-load-balancing"
    health_probe_name   = "api-health-probe"
  }

  backend_pool_load_balancing {
    name                            = "api-load-balancing"
    sample_size                     = 4
    successful_samples_required     = 2
    additional_latency_milliseconds = 0
  }

  backend_pool_health_probe {
    name                = "api-health-probe"
    protocol            = "Https"
    path                = "/status-0123456789abcdef"
    interval_in_seconds = 30
  }

  frontend_endpoint {
    name                              = "api-frontend"
    host_name                         = "${var.frontdoor_name}.azurefd.net"
    session_affinity_enabled          = false
    session_affinity_ttl_seconds      = 0
    web_application_firewall_policy_link_id = azurerm_frontdoor_firewall_policy.main.id
  }

  frontend_endpoint {
    name                              = "custom-domain"
    host_name                         = var.domain_name
    session_affinity_enabled          = false
    session_affinity_ttl_seconds      = 0
    web_application_firewall_policy_link_id = azurerm_frontdoor_firewall_policy.main.id
  }

  tags = var.tags
}

resource "azurerm_frontdoor_custom_https_configuration" "main" {
  frontend_endpoint_id              = azurerm_frontdoor.main.frontend_endpoint[1].id
  custom_https_provisioning_enabled = true
  
  custom_https_configuration {
    certificate_source = "FrontDoor"
  }
}

resource "cloudflare_zone" "main" {
  zone = var.cloudflare_zone_name
}