terraform {
  required_version = "1.8.3"
  required_providers {
    kubernetes = {
        version = "~>2.0"
    }
  }
}

provider "kubernetes" {
  config_path = "./config"
}

locals {
  label_name = "gitlab-runner"
}

variable "virtual_cluster_name" {
  type = string
  default = "gitlab-runners"
}

variable "docker_pull_secret" {
  type = string
  default = "docker.company.com"
}

resource "kubernetes_secret" "docker_pull_secret" {
  metadata {
    name = var.docker_pull_secret
    namespace = var.virtual_cluster_name
  }

  data = {
    ".dockerconfigjson" = "{\"auths\": {\"docker.company.com\": {\"username\": \"ci-username\", \"password\": \"ci-password\", \"email\": \"ci-user@mail.com\"}}}"
  }
  type = "kubernetes.io/dockerconfigjson"
}

resource "kubernetes_config_map" "gitlab_runner_config" {
  metadata {
    name = "gitlab-runner-config"
    namespace = var.virtual_cluster_name
    labels = {
      label = local.label_name
    }
  }

  data = {
    "config.toml" = templatefile("./runner-config-toml.tpl", 
    {
        name = "gitlab-runner"
        token = "my-gitlab-token"
        docker_pull_secret = var.docker_pull_secret
        namespace = var.virtual_cluster_name
    })
  }
}

resource "kubernetes_persistent_volume" "maven_local_volume" {
  metadata {
    name = "gitlab-runner-mvn-local-volume"
  }
  spec {
    access_modes = [ "ReadWriteOnce" ]
    capacity = {
      storage = "5Gi"
    }
    persistent_volume_source {
      host_path {
        path = "/mnt/.m2"
      }
    }
  }
}

resource "kubernetes_secret" "gitlab_token" {
  metadata {
    name = "gitlab-access-token"
    namespace = var.virtual_cluster_name
    labels = {
      label = local.label_name
    }
  }

  data = {
    GITLAB_CI_TOKEN = "my-gitlab-ci-token"
  }
}

resource "kubernetes_deployment" "gitlab_runner_deployment" {
  metadata {
    name = "gitlab-runner"
    namespace = var.virtual_cluster_name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        label = local.label_name
      }
    }

    template {
      metadata {
        name = "gitlab-runner"
        namespace = var.virtual_cluster_name
        labels = {
          label = local.label_name
        }
      }
      spec {
        automount_service_account_token = true
        service_account_name = "gitlab-runner-admin"
        image_pull_secrets {
          name = var.docker_pull_secret
        }
        dns_policy = "None"
        dns_config {
          nameservers = [ "xx.xx.xx.xx" ]
          searches = [ "gitlab.company.com" ]
        }
        container {
          name = "gitlab-runner"
          image = "gitlab/gitlab-runner:v16.11.0"
          image_pull_policy = "Always"

          args = [ "run" ]

          volume_mount {
            mount_path = "/etc/gitlab-runner"
            name = "config"
          }
          volume_mount {
            mount_path = "/etc/ssl/certs"
            name = "cacerts"
            read_only = true
          }
        }

        restart_policy = "Always"
        
        volume {
          config_map {
            name = "gilab-runner-config"
          }
          name = "config"
        }
        volume {
            host_path {
                path = "/usr/share/ca-certificates/mozilla"
            }  
            name = "cacerts"
        }
      }
    }
  }
}

resource "kubernetes_service_account" "gitlab_runner_service_account" {
  metadata {
    name = "gitlab-runner-admin"
    namespace = var.virtual_cluster_name
  }
  image_pull_secret {
    name = "docker-secret"
  }
  secret {
    name = "gitlab-ci-token"
  }
  automount_service_account_token = true
}

resource "kubernetes_role" "gitlab_ci_role" {
  metadata {
    name = "gitlab-runner-role"
    namespace = var.virtual_cluster_name
    labels = {
      label = local.label_name
    }
  }
  rule {
    api_groups = [ "" ]
    resources = [ "" ]
    verbs = [ "" ]
  }
}

resource "kubernetes_role_binding" "gitlab_ci_role_binding" {
  metadata {
    name = "gitlab-runner-role-binding"
    namespace = var.virtual_cluster_name
  }
  subject {
    kind = "ServiceAccount"
    name = "gitlab-runner-admin"
    namespace = var.virtual_cluster_name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "Role"
    name = "gitlab-runner-role"
  }
}
