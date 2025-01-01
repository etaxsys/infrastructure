# A modified copy of https://github.com/cloudposse/terraform-aws-eks-cluster/tree/main/examples/complete/fixtures.us-east-2.tfvars
region = "us-east-1"

availability_zones = ["us-east-1a", "us-east-1b"]

namespace = "vpc1"

stage = "dev"

name = "eks"

# oidc_provider_enabled is required to be true for VPC CNI addon
oidc_provider_enabled = true

enabled_cluster_log_types = ["audit"]

cluster_log_retention_period = 7

instance_types = ["t3.medium"]

# *** NOTE *** if you want to change desired_size, you'll need to taint and recreate the node_group! This due to CloudPosse lifecycle setting.
# Original values:
# desired_size = 2
# max_size = 3
# min_size = 2
desired_size = 3
max_size = 5
min_size = 3

kubernetes_labels = {}

cluster_encryption_config_enabled = true

# When updating the Kubernetes version, also update the API and client-go version in test/src/go.mod
kubernetes_version = "1.29"

private_ipv6_enabled = false

addons = [
  # https://docs.aws.amazon.com/eks/latest/userguide/managing-kube-proxy.html
  {
    addon_name                  = "kube-proxy"
    addon_version               = null
    resolve_conflicts_on_create = "OVERWRITE"
    resolve_conflicts_on_update = "PRESERVE"
    service_account_role_arn    = null
  },
  # https://docs.aws.amazon.com/eks/latest/userguide/managing-coredns.html
  {
    addon_name               = "coredns"
    addon_version            = null
    resolve_conflicts        = "NONE"
    service_account_role_arn = null
  },
]

upgrade_policy = {
  support_type = "STANDARD"
}

zonal_shift_config = {
  enabled = true
}
