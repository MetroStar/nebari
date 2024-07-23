# ======================= VARIABLES ======================
variable "conda-store-environments" {
  description = "Conda-Store managed environments"
}

variable "conda-store-filesystem-storage" {
  description = "Conda-Store storage in GB for filesystem environments that are built"
  type        = string
}

variable "conda-store-object-storage" {
  description = "Conda-Store storage in GB for object storage. Conda-Store uses minio for object storage to be cloud agnostic. If empty default is var.conda-store-filesystem-storage value"
  type        = string
}

variable "conda-store-extra-settings" {
  description = "Conda-Store extra traitlet settings to apply in `c.Class.key = value` form"
  type        = map(any)
}

variable "conda-store-extra-config" {
  description = "Additional traitlets configuration code to be ran"
  type        = string
}

variable "conda-store-image" {
  description = "Conda-Store image"
  type        = string
}

variable "conda-store-image-tag" {
  description = "Version of conda-store to use"
  type        = string
}

variable "conda-store-nfs-image" {
  description = "Conda-Store volume nfs server image"
  type        = string
}

variable "conda-store-nfs-image-tag" {
  description = "Version of conda-store volume nfs server to use"
  type        = string
}

variable "conda-store-service-token-scopes" {
  description = "Map of services tokens and scopes for conda-store"
  type        = map(any)
}

variable "conda-store-minio-overrides" {
  description = "Minio helm chart overrides"
  type        = list(string)
  default     = []
}

variable "conda-store-postgresql-overrides" {
  description = "Postgresql helm chart overrides"
  type        = list(string)
  default     = []
}

variable "conda-store-redis-overrides" {
  description = "Redis helm chart overrides"
  type        = list(string)
  default     = []
}

# ====================== RESOURCES =======================
module "kubernetes-conda-store-server" {
  source = "./modules/kubernetes/services/conda-store"

  name      = "nebari"
  namespace = var.environment

  external-url = var.endpoint
  realm_id     = var.realm_id

  nfs_capacity              = var.conda-store-filesystem-storage
  minio_capacity            = coalesce(var.conda-store-object-storage, var.conda-store-filesystem-storage)
  node-group                = var.node_groups.general
  conda-store-image         = var.conda-store-image
  conda-store-image-tag     = var.conda-store-image-tag
  conda-store-nfs-image     = var.conda-store-nfs-image
  conda-store-nfs-image-tag = var.conda-store-nfs-image-tag
  default-namespace-name = var.conda-store-default-namespace
  environments = {
    for filename, environment in var.conda-store-environments :
    filename => yamlencode(environment)
  }
  services       = var.conda-store-service-token-scopes
  extra-settings = var.conda-store-extra-settings
  extra-config   = var.conda-store-extra-config

  conda-store-minio-overrides = var.conda-store-minio-overrides
  conda-store-postgresql-overrides = var.conda-store-postgresql-overrides
  conda-store-redis-overrides = var.conda-store-redis-overrides
}

module "conda-store-nfs-mount" {
  source = "./modules/kubernetes/nfs-mount"

  name         = "conda-store"
  namespace    = var.environment
  nfs_capacity = var.conda-store-filesystem-storage
  nfs_endpoint = module.kubernetes-conda-store-server.endpoint_ip

  depends_on = [
    module.kubernetes-conda-store-server
  ]
}
