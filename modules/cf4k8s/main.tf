resource "kubernetes_namespace" "cf" {
  metadata {
    name = "cf-system"
  }
}

resource "random_password" "gen" {
  length = 24
  special = false
}

data "local_file" "certs_vars" {
  filename = "${path.module}/certs.auto.tfvars"
}

data "template_file" "cf4k8s_config" {
  template = file("${path.module}/templates/config.yml")

  vars = {
    system_domain = local.system_domain
    app_domain = local.app_domain

    system_fullchain_certificate = element(split(" = ", element(split("\n", data.local_file.certs_vars.content), 0)), 1)
    system_private_key = element(split(" = ", element(split("\n", data.local_file.certs_vars.content), 1)), 1)
    workloads_fullchain_certificate = element(split(" = ", element(split("\n", data.local_file.certs_vars.content), 2)), 1)
    workloads_private_key = element(split(" = ", element(split("\n", data.local_file.certs_vars.content), 3)), 1)

    cf_admin_password = random_password.gen.result

    registry_domain     = var.registry_domain
    repository_prefix = var.repository_prefix
    registry_username   = var.registry_username
    registry_password   = var.registry_password
  }
}

resource "local_file" "cf4k8s_config_rendered" {
  content     = data.template_file.cf4k8s_config.rendered
  filename = "${path.module}/${var.ytt_lib_dir}/cf4k8s/vendor/config-rendered.yml"
}

data "template_file" "cf4k8s_cert" {
  template = file("${path.module}/templates/cert.yml")

  vars = {
    system_domain = local.system_domain
    app_domain = local.app_domain
    namespace     = kubernetes_namespace.cf.metadata[0].name
  }
}

resource "local_file" "cf4k8s_cert_rendered" {
  content     = data.template_file.cf4k8s_cert.rendered
  filename = "${path.module}/${var.ytt_lib_dir}/cf4k8s/vendor/cert-rendered.yml"
}

resource "k14s_kapp" "cf4k8s_cert" {
  app = "cf4k8s-cert"

  namespace = "default"

  config_yaml = data.template_file.cf4k8s_cert.rendered

  debug_logs = true

  depends_on = [
    local_file.cf4k8s_cert_rendered
  ]
}

data "k14s_ytt" "cf4k8s_ytt" {
  files = [
    "${path.module}/${var.ytt_lib_dir}/cf4k8s/vendor/github.com/cloudfoundry/cf-for-k8s/config"
  ]

  debug_logs = true

  config_yaml = data.template_file.cf4k8s_config.rendered

  depends_on = [
    local_file.cf4k8s_config_rendered
  ]
}

resource "local_file" "cf4k8s_ytt" {
  content = data.k14s_ytt.cf4k8s_ytt.result
  filename = "${path.module}/${var.ytt_lib_dir}/cf4k8s/vendor/config-ytt.yml"
}

resource "k14s_kapp" "cf4k8s" {
  app = "cf"
  namespace = "default"

  config_yaml = data.k14s_ytt.cf4k8s_ytt.result

  debug_logs = true

  depends_on = [
    k14s_kapp.cf4k8s_cert,
    local_file.cf4k8s_ytt
  ]

}