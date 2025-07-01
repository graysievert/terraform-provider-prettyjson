# Advanced Complex Data Structure Examples: PrettyJSON Provider
# This example demonstrates advanced usage patterns for the prettyjson provider
# with complex nested data structures, jsonencode() integration, and real-world scenarios.

terraform {
  required_providers {
    prettyjson = {
      source = "hashicorp/prettyjson"
    }
    local = {
      source = "hashicorp/local"
    }
    random = {
      source = "hashicorp/random"
    }
  }
  required_version = ">= 1.8.0"
}

# Variables for complex data structure examples
variable "microservices" {
  description = "Microservices configuration"
  type = map(object({
    image    = string
    replicas = number
    ports    = list(number)
    env_vars = map(string)
    resources = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
    health_check = object({
      path     = string
      port     = number
      interval = number
      timeout  = number
    })
  }))
  default = {
    api = {
      image    = "api:v1.2.3"
      replicas = 3
      ports    = [8080, 8443]
      env_vars = {
        LOG_LEVEL = "info"
        DB_HOST   = "postgres.internal"
        CACHE_URL = "redis.internal:6379"
      }
      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }
      health_check = {
        path     = "/health"
        port     = 8080
        interval = 30
        timeout  = 5
      }
    }
    worker = {
      image    = "worker:v1.2.3"
      replicas = 2
      ports    = [8090]
      env_vars = {
        LOG_LEVEL   = "debug"
        QUEUE_URL   = "amqp://rabbitmq.internal"
        WORKER_TYPE = "background"
      }
      resources = {
        requests = {
          cpu    = "200m"
          memory = "256Mi"
        }
        limits = {
          cpu    = "1000m"
          memory = "1Gi"
        }
      }
      health_check = {
        path     = "/status"
        port     = 8090
        interval = 60
        timeout  = 10
      }
    }
  }
}

variable "infrastructure_config" {
  description = "Infrastructure configuration with nested objects"
  type = object({
    vpc = object({
      cidr_block           = string
      enable_dns_hostnames = bool
      enable_dns_support   = bool
      subnets = map(object({
        cidr_block        = string
        availability_zone = string
        public            = bool
      }))
    })
    security_groups = map(object({
      description = string
      ingress_rules = list(object({
        from_port   = number
        to_port     = number
        protocol    = string
        cidr_blocks = list(string)
        description = string
      }))
      egress_rules = list(object({
        from_port   = number
        to_port     = number
        protocol    = string
        cidr_blocks = list(string)
        description = string
      }))
    }))
    databases = map(object({
      engine         = string
      engine_version = string
      instance_class = string
      storage = object({
        allocated     = number
        max_allocated = number
        encrypted     = bool
        type          = string
      })
      backup = object({
        retention_period = number
        window           = string
        final_snapshot   = bool
      })
    }))
  })
  default = {
    vpc = {
      cidr_block           = "10.0.0.0/16"
      enable_dns_hostnames = true
      enable_dns_support   = true
      subnets = {
        public_1 = {
          cidr_block        = "10.0.1.0/24"
          availability_zone = "us-west-2a"
          public            = true
        }
        public_2 = {
          cidr_block        = "10.0.2.0/24"
          availability_zone = "us-west-2b"
          public            = true
        }
        private_1 = {
          cidr_block        = "10.0.10.0/24"
          availability_zone = "us-west-2a"
          public            = false
        }
        private_2 = {
          cidr_block        = "10.0.20.0/24"
          availability_zone = "us-west-2b"
          public            = false
        }
      }
    }
    security_groups = {
      web = {
        description = "Security group for web servers"
        ingress_rules = [
          {
            from_port   = 80
            to_port     = 80
            protocol    = "tcp"
            cidr_blocks = ["0.0.0.0/0"]
            description = "HTTP access"
          },
          {
            from_port   = 443
            to_port     = 443
            protocol    = "tcp"
            cidr_blocks = ["0.0.0.0/0"]
            description = "HTTPS access"
          }
        ]
        egress_rules = [
          {
            from_port   = 0
            to_port     = 0
            protocol    = "-1"
            cidr_blocks = ["0.0.0.0/0"]
            description = "All outbound traffic"
          }
        ]
      }
      database = {
        description = "Security group for database servers"
        ingress_rules = [
          {
            from_port   = 5432
            to_port     = 5432
            protocol    = "tcp"
            cidr_blocks = ["10.0.0.0/16"]
            description = "PostgreSQL access from VPC"
          }
        ]
        egress_rules = []
      }
    }
    databases = {
      primary = {
        engine         = "postgres"
        engine_version = "14.9"
        instance_class = "db.r5.large"
        storage = {
          allocated     = 100
          max_allocated = 1000
          encrypted     = true
          type          = "gp3"
        }
        backup = {
          retention_period = 7
          window           = "03:00-04:00"
          final_snapshot   = true
        }
      }
    }
  }
}

# Local values for complex data processing
locals {
  # Process microservices data with transformations
  processed_microservices = {
    for service_name, config in var.microservices : service_name => {
      metadata = {
        name        = service_name
        image       = config.image
        replicas    = config.replicas
        total_ports = length(config.ports)
        has_https   = contains(config.ports, 443) || contains(config.ports, 8443)
      }
      runtime = {
        ports = [
          for port in config.ports : {
            number   = port
            protocol = port == 443 || port == 8443 ? "https" : "http"
            name     = port == 443 || port == 8443 ? "secure" : "standard"
          }
        ]
        environment = merge(config.env_vars, {
          SERVICE_NAME  = upper(service_name)
          REPLICA_COUNT = tostring(config.replicas)
          PORTS_JSON    = jsonencode(config.ports)
        })
        health = merge(config.health_check, {
          endpoint   = "http://localhost:${config.health_check.port}${config.health_check.path}"
          timeout_ms = config.health_check.timeout * 1000
        })
      }
      kubernetes = {
        deployment = {
          apiVersion = "apps/v1"
          kind       = "Deployment"
          metadata = {
            name = service_name
            labels = {
              app     = service_name
              version = split(":", config.image)[1]
            }
          }
          spec = {
            replicas = config.replicas
            selector = {
              matchLabels = {
                app = service_name
              }
            }
            template = {
              metadata = {
                labels = {
                  app = service_name
                }
              }
              spec = {
                containers = [
                  {
                    name  = service_name
                    image = config.image
                    ports = [
                      for port in config.ports : {
                        containerPort = port
                        protocol      = "TCP"
                      }
                    ]
                    env = [
                      for key, value in config.env_vars : {
                        name  = key
                        value = value
                      }
                    ]
                    resources = config.resources
                    livenessProbe = {
                      httpGet = {
                        path = config.health_check.path
                        port = config.health_check.port
                      }
                      initialDelaySeconds = 30
                      periodSeconds       = config.health_check.interval
                      timeoutSeconds      = config.health_check.timeout
                    }
                    readinessProbe = {
                      httpGet = {
                        path = config.health_check.path
                        port = config.health_check.port
                      }
                      initialDelaySeconds = 5
                      periodSeconds       = 10
                      timeoutSeconds      = config.health_check.timeout
                    }
                  }
                ]
              }
            }
          }
        }
      }
    }
  }

  # Complex AWS infrastructure configuration
  aws_infrastructure = merge(var.infrastructure_config, {
    computed = {
      total_subnets = length(var.infrastructure_config.vpc.subnets)
      public_subnets = [
        for subnet_name, subnet in var.infrastructure_config.vpc.subnets : subnet_name if subnet.public
      ]
      private_subnets = [
        for subnet_name, subnet in var.infrastructure_config.vpc.subnets : subnet_name if !subnet.public
      ]
      security_group_rules_count = {
        for sg_name, sg in var.infrastructure_config.security_groups : sg_name => {
          ingress = length(sg.ingress_rules)
          egress  = length(sg.egress_rules)
          total   = length(sg.ingress_rules) + length(sg.egress_rules)
        }
      }
      database_summary = {
        for db_name, db in var.infrastructure_config.databases : db_name => {
          identifier     = "${db_name}-${db.engine}-${replace(db.engine_version, ".", "-")}"
          storage_gb     = db.storage.allocated
          backup_enabled = db.backup.retention_period > 0
          encrypted      = db.storage.encrypted
        }
      }
    }
  })

  # Nested configuration with multiple levels of data transformation
  application_stack = {
    metadata = {
      name        = "complex-microservices-stack"
      version     = "2.1.0"
      environment = "production"
      created_by  = "terraform"
      timestamp   = timestamp()
    }
    infrastructure = local.aws_infrastructure
    services       = local.processed_microservices
    monitoring = {
      prometheus = {
        enabled = true
        config = {
          global = {
            scrape_interval     = "15s"
            evaluation_interval = "15s"
          }
          scrape_configs = [
            for service_name, config in var.microservices : {
              job_name = service_name
              static_configs = [
                {
                  targets = [
                    for port in config.ports : "localhost:${port}"
                  ]
                }
              ]
              metrics_path    = "/metrics"
              scrape_interval = "30s"
            }
          ]
        }
      }
      grafana = {
        enabled = true
        dashboards = {
          for service_name, config in var.microservices : service_name => {
            title = "${title(service_name)} Service Dashboard"
            panels = [
              {
                title = "Request Rate"
                type  = "graph"
                targets = [
                  {
                    expr = "rate(http_requests_total{service=\"${service_name}\"}[5m])"
                  }
                ]
              },
              {
                title = "Error Rate"
                type  = "graph"
                targets = [
                  {
                    expr = "rate(http_requests_total{service=\"${service_name}\",status!~\"2..\"}[5m])"
                  }
                ]
              },
              {
                title = "Response Time"
                type  = "graph"
                targets = [
                  {
                    expr = "histogram_quantile(0.95, rate(http_duration_seconds_bucket{service=\"${service_name}\"}[5m]))"
                  }
                ]
              }
            ]
          }
        }
      }
    }
    backup_and_recovery = {
      strategy = "multi-tier"
      components = {
        database = {
          automated_backups = {
            for db_name, db in var.infrastructure_config.databases : db_name => {
              enabled           = true
              retention_days    = db.backup.retention_period
              backup_window     = db.backup.window
              final_snapshot    = db.backup.final_snapshot
              cross_region_copy = true
            }
          }
        }
        application_data = {
          s3_backups = {
            bucket = "app-backups-${random_id.backup_suffix.hex}"
            lifecycle = {
              standard_to_ia_days          = 30
              ia_to_glacier_days           = 90
              glacier_to_deep_archive_days = 365
              expiration_days              = 2555 # 7 years
            }
            versioning = true
            encryption = {
              algorithm = "AES256"
              kms_key   = true
            }
          }
        }
      }
    }
  }
}

# Random ID for unique naming
resource "random_id" "backup_suffix" {
  byte_length = 4
}

# Example 1: Complex microservices configuration with multiple indentation styles
resource "local_file" "microservices_config_2spaces" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.processed_microservices),
    "2spaces"
  )
  filename        = "${path.module}/generated/microservices-2spaces.json"
  file_permission = "0644"
}

resource "local_file" "microservices_config_4spaces" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.processed_microservices),
    "4spaces"
  )
  filename        = "${path.module}/generated/microservices-4spaces.json"
  file_permission = "0644"
}

resource "local_file" "microservices_config_tabs" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.processed_microservices),
    "tab"
  )
  filename        = "${path.module}/generated/microservices-tabs.json"
  file_permission = "0644"
}

# Example 2: AWS infrastructure configuration
resource "local_file" "aws_infrastructure_config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.aws_infrastructure),
    "4spaces"
  )
  filename        = "${path.module}/generated/aws-infrastructure.json"
  file_permission = "0644"
}

# Example 3: Complete application stack configuration
resource "local_file" "application_stack_config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.application_stack),
    "2spaces"
  )
  filename        = "${path.module}/generated/application-stack.json"
  file_permission = "0644"
}

# Example 4: Individual Kubernetes manifests for each service
resource "local_file" "kubernetes_manifests" {
  for_each = local.processed_microservices

  content = provider::prettyjson::jsonprettyprint(
    jsonencode(each.value.kubernetes.deployment),
    "2spaces"
  )
  filename        = "${path.module}/generated/k8s-${each.key}-deployment.json"
  file_permission = "0644"
}

# Example 5: Monitoring configuration files
resource "local_file" "prometheus_config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.application_stack.monitoring.prometheus.config),
    "4spaces"
  )
  filename        = "${path.module}/generated/prometheus-config.json"
  file_permission = "0644"
}

resource "local_file" "grafana_dashboards" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.application_stack.monitoring.grafana.dashboards),
    "2spaces"
  )
  filename        = "${path.module}/generated/grafana-dashboards.json"
  file_permission = "0644"
}

# Example 6: Nested data processing with jsonencode() integration
resource "local_file" "processed_service_data" {
  for_each = var.microservices

  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      original_config  = each.value
      processed_config = local.processed_microservices[each.key]
      terraform_metadata = {
        workspace   = terraform.workspace
        timestamp   = timestamp()
        service_key = each.key
      }
      computed_values = {
        resource_ratio = "${each.value.resources.requests.cpu}:${each.value.resources.limits.cpu}"
        memory_ratio   = "${each.value.resources.requests.memory}:${each.value.resources.limits.memory}"
        health_url     = "http://localhost:${each.value.health_check.port}${each.value.health_check.path}"
        env_count      = length(each.value.env_vars)
        port_count     = length(each.value.ports)
      }
    }),
    "tab"
  )
  filename        = "${path.module}/generated/service-${each.key}-processed.json"
  file_permission = "0644"
}

# Example 7: Dynamic data transformation with complex logic
resource "local_file" "deployment_matrix" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      deployment_strategy = "rolling"
      environments = {
        for env in ["dev", "staging", "prod"] : env => {
          services = {
            for service_name, config in var.microservices : service_name => {
              replicas = env == "prod" ? config.replicas * 2 : (env == "staging" ? config.replicas : 1)
              resources = env == "prod" ? {
                requests = config.resources.limits
                limits = {
                  cpu    = "${parseint(split("m", config.resources.limits.cpu)[0], 10) * 2}m"
                  memory = "${parseint(split("Mi", config.resources.limits.memory)[0], 10) * 2}Mi"
                }
              } : config.resources
              monitoring = {
                enabled = env != "dev"
                level   = env == "prod" ? "detailed" : "basic"
              }
            }
          }
          infrastructure = {
            instance_types     = env == "prod" ? ["m5.large", "m5.xlarge"] : ["t3.medium"]
            availability_zones = env == "prod" ? 3 : (env == "staging" ? 2 : 1)
            auto_scaling = {
              enabled      = env != "dev"
              min_capacity = env == "prod" ? 2 : 1
              max_capacity = env == "prod" ? 10 : 3
            }
          }
        }
      }
      backup_config = local.application_stack.backup_and_recovery
    }),
    "4spaces"
  )
  filename        = "${path.module}/generated/deployment-matrix.json"
  file_permission = "0644"
}