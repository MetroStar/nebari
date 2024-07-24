variable "monitoring-enabled" {
  description = "Prometheus and Grafana monitoring enabled"
  type        = bool
}

variable "prometheus-overrides" {
  description = "Grafana helm chart overrides"
  type        = list(string)
}

module "monitoring" {
  count = var.monitoring-enabled ? 1 : 0

  source               = "./modules/kubernetes/services/monitoring"
  namespace            = var.environment
  external-url         = var.endpoint
  realm_id             = var.realm_id
  jupyterhub_api_token = module.jupyterhub.services.monitoring.api_token
  overrides            = var.prometheus-overrides

  node-group = var.node_groups.general
}

module "grafana-loki" {
  count                        = var.monitoring-enabled ? 1 : 0
  source                       = "./modules/kubernetes/services/monitoring/loki"
  namespace                    = var.environment
  grafana-loki-overrides       = var.grafana-loki-overrides
  grafana-promtail-overrides   = var.grafana-promtail-overrides
  grafana-loki-minio-overrides = var.grafana-loki-minio-overrides
  node-group                   = var.node_groups.general
  minio-enabled                = var.minio-enabled
}
