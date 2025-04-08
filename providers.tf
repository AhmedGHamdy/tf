variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "api-infrastructure-rg"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "app_service_plan_name" {
  description = "Name of the App Service Plan"
  type        = string
  default     = "api-backend-plan"
}

variable "app_service_name" {
  description = "Name of the App Service"
  type        = string
  default     = "api-backend-app"
}

variable "app_service_sku" {
  description = "SKU for the App Service Plan"
  type        = string
  default     = "P1v2"
}

variable "api_management_name" {
  description = "Name of the API Management service"
  type        = string
  default     = "api-management-service"
}

variable "api_management_sku" {
  description = "SKU for the API Management"
  type        = string
  default     = "Developer_1"
}

variable "api_management_publisher_name" {
  description = "Publisher name for API Management"
  type        = string
  default     = "My Organization"
}

variable "api_management_publisher_email" {
  description = "Publisher email for API Management"
  type        = string
  default     = "admin@example.com"
}

variable "frontdoor_name" {
  description = "Name of the Front Door service"
  type        = string
  default     = "api-frontdoor"
}

variable "frontdoor_waf_name" {
  description = "Name of the Front Door WAF policy"
  type        = string
  default     = "api-frontdoor-waf"
}

variable "domain_name" {
  description = "Primary domain name for the API"
  type        = string
  default     = "api.example.com"
}

variable "cloudflare_zone_name" {
  description = "Cloudflare zone name (domain)"
  type        = string
  default     = "example.com"
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Production"
    Project     = "API Infrastructure"
  }
}