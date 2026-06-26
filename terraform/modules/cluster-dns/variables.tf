variable "zone_name" {
  description = "Route53 hosted zone name (e.g. cluster-dev.adamjhall.dev)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
