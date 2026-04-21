variable "yourname" {
  description = "Your name, lowercase, no spaces. Used to make resource names unique."
  type = string
}

variable "location" {
  description = "Azure region for the staging and target migration resources."
  type        = string
  default     = "East US"
}

variable "tags" {
  type = map(string)
  default = {
    project    = "azure-migrate-lab"
    managed_by = "terraform"
  }
}

variable "appliance_admin_password" {
  description = "Admin password for the migration appliance VM."
  type        = string
  sensitive   = true
}

variable "replication_admin_password" {
  description = "Admin password for the replication appliance VM."
  type        = string
  sensitive   = true
}
