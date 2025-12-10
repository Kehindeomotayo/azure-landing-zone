variable "location" {
  type        = string
  description = "Azure region for all resources"
  default     = "East US"
}

variable "ssh_public_key" {
  type        = string
  description = "Public SSH key for VM authentication"
}

variable "security_contact_email" {
  type        = string
  description = "Email address for security alerts and notifications"
}
