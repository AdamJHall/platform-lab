variable "name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the cluster"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to deploy the cluster into"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the cluster and node groups"
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Whether the cluster API endpoint is publicly accessible"
  type        = bool
  default     = false
}

variable "eks_managed_node_groups" {
  description = "Map of EKS managed node group definitions"
  type        = any
  default     = {}
}

variable "additional_admin_role_arns" {
  description = "IAM role ARNs granted AmazonEKSClusterAdminPolicy (e.g. the CI apply role)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
