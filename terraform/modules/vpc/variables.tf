variable "name" {
  description = "Name of the VPC"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrnetmask(var.cidr_block)) && cidrsubnet(var.cidr_block, 0, 0) == var.cidr_block
    error_message = "cidr_block must be a valid IPv4 CIDR with no host bits set (e.g. 10.0.0.0/16)."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "az_count" {
  description = "Number of AZs to create subnets in."
  type        = number
  default     = 2
  validation {
    condition     = var.az_count >= 1 && var.az_count <= 6
    error_message = "az_count must be between 1 and 6."
  }
}

variable "nat_use_spot_instances" {
  description = "Enable / disable  spot pricing on the fck-nat instances."
  type        = bool
  default     = true
}

variable "nat_instance_type" {
  description = "EC2 instance type for fck-nat. Default to t4g.nano."
  type        = string
  default     = "t4g.nano"
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs."
  type        = bool
  default     = true
}

variable "subnet_cidrs" {
  description = "CIDRs used for each subnet type. CIDR count per type must match az_count."
  type = object({
    public              = list(string)
    private             = list(string)
    private_with_egress = list(string)
  })
  validation {
    condition = (
      length(var.subnet_cidrs.public) == var.az_count &&
      length(var.subnet_cidrs.private) == var.az_count &&
      length(var.subnet_cidrs.private_with_egress) == var.az_count
    )
    error_message = "Each entry in subnet_cidrs must have exactly az_count entries."
  }
  validation {
    condition = alltrue([
      for cidr in concat(var.subnet_cidrs.public, var.subnet_cidrs.private, var.subnet_cidrs.private_with_egress) :
      can(cidrnetmask(cidr)) && cidrsubnet(cidr, 0, 0) == cidr
    ])
    error_message = "All subnet CIDRs must be valid IPv4 CIDRs with no host bits set (e.g. 10.0.0.0/24)."
  }
  validation {
    condition = alltrue([
      for cidr in concat(var.subnet_cidrs.public, var.subnet_cidrs.private, var.subnet_cidrs.private_with_egress) :
      cidrcontains(var.cidr_block, cidr)
    ])
    error_message = "All subnet CIDRs must fall within the VPC CIDR block."
  }
}

variable "subnet_tags" {
  description = "Extra tags to add to each subnet."
  type = object({
    public              = optional(map(string), {})
    private             = optional(map(string), {})
    private_with_egress = optional(map(string), {})
  })
  default = {}
}