data "aws_partition" "current" {}

resource "aws_eks_cluster" "main" {
  name     = var.name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    security_group_ids = var.cluster_security_groups
    subnet_ids         = var.cluster_subnets

    endpoint_private_access = var.endpoint_private_access
    public_access_cidrs     = var.public_access_cidrs
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster-policy,
  ]

  tags = merge({ Name = var.name }, var.tags)
}

resource "aws_launch_template" "main" {
  # Invoke launch_template only if var.node_prebootstrap_command is not null
  count = var.node_prebootstrap_command == null ? 0 : length(var.node_groups)
  name  = var.node_groups[count.index].name

  vpc_security_group_ids = var.cluster_security_groups

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 50
      volume_type = "gp2"
    }
  }
  # https://docs.aws.amazon.com/eks/latest/userguide/launch-templates.html#launch-template-basics
  user_data                     = base64encode(<<-EOF
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="//"
--//
Content-Type: text/x-shellscript; charset="us-ascii"
${var.node_prebootstrap_command}

--//--\
  EOF
  )
}

resource "aws_eks_node_group" "main" {
  count = length(var.node_groups)

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = var.node_groups[count.index].name
  node_role_arn   = aws_iam_role.node-group.arn
  subnet_ids      = var.node_groups[count.index].single_subnet ? [element(var.cluster_subnets, 0)] : var.cluster_subnets

  instance_types = [var.node_groups[count.index].instance_type]
  ami_type       = var.node_groups[count.index].gpu == true ? "AL2_x86_64_GPU" : "AL2_x86_64"
  disk_size      = var.node_prebootstrap_command == null ? 50 : null

  scaling_config {
    min_size     = var.node_groups[count.index].min_size
    desired_size = var.node_groups[count.index].desired_size
    max_size     = var.node_groups[count.index].max_size
  }

  labels = {
    "dedicated" = var.node_groups[count.index].name
  }

  lifecycle {
    ignore_changes = [
      scaling_config[0].desired_size,
    ]
  }

  # Invoke launch_template only if var.node_prebootstrap_command is not null
  dynamic "launch_template" {
    for_each = var.node_prebootstrap_command == null ? [] : [1]
    content {
      id = aws_launch_template.main[count.index].id
      version = aws_launch_template.main[count.index].latest_version
    }
  }

  # Ensure that IAM Role permissions are created before and deleted
  # after EKS Node Group handling.  Otherwise, EKS will not be able to
  # properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.node-group-policy,
  ]

  tags = merge({
    "k8s.io/cluster-autoscaler/node-template/label/dedicated" = var.node_groups[count.index].name
    propagate_at_launch                                       = true
  }, var.tags)
}

data "aws_eks_cluster_auth" "main" {
  name = aws_eks_cluster.main.name
}

resource "aws_eks_addon" "aws-ebs-csi-driver" {
  # required for Kubernetes v1.23+ on AWS
  addon_name                  = "aws-ebs-csi-driver"
  cluster_name                = aws_eks_cluster.main.name
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  configuration_values = jsonencode({
    controller = {
      nodeSelector = {
        "eks.amazonaws.com/nodegroup" = "general"
      }
    }
  })

  # Ensure cluster and node groups are created
  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.main,
  ]
}

resource "aws_eks_addon" "coredns" {
  addon_name                  = "coredns"
  cluster_name                = aws_eks_cluster.main.name
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"


  configuration_values = jsonencode({
    nodeSelector = {
      "eks.amazonaws.com/nodegroup" = "general"
    }
  })

  # Ensure cluster and node groups are created
  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.main,
  ]
}

data "tls_certificate" "this" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "oidc_provider" {
  client_id_list  = ["sts.${data.aws_partition.current.dns_suffix}"]
  thumbprint_list = data.tls_certificate.this.certificates[*].sha1_fingerprint
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(
    { Name = "${var.name}-eks-irsa" },
    var.tags
  )
}
