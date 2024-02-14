module "kubernetes-ingress" {
  source = "./modules/kubernetes/ingress"

  namespace = var.environment

  node-group = var.node_groups.general

  traefik-image = var.traefik-image

  certificate-service       = var.certificate-service
  acme-email                = var.acme-email
  acme-server               = var.acme-server
  certificate-secret-name   = var.certificate-secret-name
  load-balancer-annotations = var.load-balancer-annotations
  load-balancer-ip          = var.load-balancer-ip
  additional-arguments      = var.additional-arguments
	# for volume persist
  volume_name       = "traefik-data"
  storage_size      = "10Gi"
  storage_class_name = "ssd-storage-clas"
  pvc_name="my-pv"

}
