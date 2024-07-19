
# ======================= VARIABLES ======================
variable "jupyterhub-ssh-image" {
  description = "image to use for jupyterhub-ssh"
  type = object({
    name = string
    tag  = string
  })
}

variable "jupyterhub-sftp-image" {
  description = "image to use for jupyterhub-sftp"
  type = object({
    name = string
    tag  = string
  })
}

# ====================== RESOURCES =======================
module "kubernetes-jupyterhub-ssh" {
  source = "./modules/kubernetes/services/jupyterhub-ssh"

  namespace          = var.environment
  jupyterhub_api_url = module.jupyterhub.internal_jupyterhub_url

  jupyterhub-ssh-image = var.jupyterhub-ssh-image
  jupyterhub-sftp-image = var.jupyterhub-sftp-image

  node-group              = var.node_groups.general
  persistent_volume_claim = module.jupyterhub-nfs-mount.persistent_volume_claim.name
}
