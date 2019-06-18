module "toolchain_namespace" {
  source     = "../../common/namespace"
  namespace  = "${var.namespace}"
  annotations {
    name = "${var.namespace}"
    cluster = "${var.cluster}"
    "opa.lead.liatrio/ingress-whitelist" = "*.${var.namespace}.${var.cluster}.${var.root_zone_name}"
    "opa.lead.liatrio/image-whitelist" = "${var.image_whitelist}"
    "opa.lead.liatrio/elb-extra-security-groups" = "${var.elb_security_group_id}"
  }
}

module "toolchain_ingress" {
  source = "../../common/nginx-ingress"
  namespace  = "${module.toolchain_namespace.name}"
  ingress_controller_type = "${var.ingress_controller_type}"
}

module "toolchain_issuer" {
  source = "../../common/cert-issuer"
  namespace  = "${module.toolchain_namespace.name}"
  issuer_type = "${var.issuer_type}"
  crd_waiter  = "${var.crd_waiter}"
}

resource "kubernetes_cluster_role" "tiller_cluster_role" {
  metadata {
    name = "toolchain-tiller-manager"
  }
  rule {
    api_groups = ["", "batch", "extensions", "apps","stable.liatr.io", "policy", "apiextensions.k8s.io"]
    resources = ["*"]
    verbs = ["*"]
  }
  rule {
    api_groups = ["apiextensions.k8s.io"]
    resources = ["customresourcedefinitions"]
    verbs = ["*"]
  }
  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources = ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
    verbs = ["get", "create", "watch", "delete", "list", "patch"]
  }
  rule {
    api_groups = ["networking.k8s.io"]
    resources = ["networkpolicies"]
    verbs = ["get", "create", "watch", "delete", "list", "patch"]
  }
  rule {
    api_groups = ["certmanager.k8s.io"]
    resources = ["issuers"]
    verbs = ["get", "create", "watch", "delete", "list", "patch"]
  }
}

resource "kubernetes_cluster_role_binding" "tiller_cluster_role_binding" {
  metadata {
    name = "toolchain-tiller-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "${kubernetes_cluster_role.tiller_cluster_role.metadata.0.name}"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "tiller"
    namespace = "${module.toolchain_namespace.name}"
  }
}