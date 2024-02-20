locals {
  ingress = kubernetes_service.main.status.0.load_balancer.0.ingress
}

output "endpoint" {
  description = "traefik load balancer endpoint"
  //  handles the case when ingress is empty list
  value = length(local.ingress) == 0 ? null : local.ingress.0
}



output "traefik_certs_pvc_name" {
  value = kubernetes_persistent_volume_claim.traefik_certs_claim.metadata.0.name
}