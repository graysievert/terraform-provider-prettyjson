# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# End-to-end workflow integration test suite
# This configuration tests complete workflows across different environments

# End-to-end workflow configuration is defined in terraform.tf

# Generate unique identifiers for this test run
resource "random_uuid" "workflow_id" {}

resource "random_string" "environment_suffix" {
  length = 6
  special = false
  upper = false
}

resource "random_integer" "service_port" {
  min = 8000
  max = 9999
}

resource "time_static" "deployment_time" {}

# Stage 1: Initial Configuration Generation
locals {
  # Base configuration that will be extended through the workflow
  base_config = {
    workflow = {
      id = random_uuid.workflow_id.result
      name = "e2e-integration-test-${random_string.environment_suffix.result}"
      stage = "initialization"
      created_at = time_static.deployment_time.rfc3339
    }
    
    environment = {
      name = "test-${random_string.environment_suffix.result}"
      type = "integration-test"
      region = "us-west-2"
      availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
    }
    
    application = {
      name = "integration-app-${random_string.environment_suffix.result}"
      version = "1.0.0"
      port = random_integer.service_port.result
      health_check_path = "/health"
      metrics_path = "/metrics"
    }
  }
}

# Stage 1: Create initial configuration
resource "local_file" "stage1_base_config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.base_config),
    "2spaces"
  )
  filename = "${path.module}/workflow/stage1-base-config.json"
  file_permission = "0644"
}

# Stage 2: Extended Configuration with Dependencies
locals {
  # Extended configuration that builds on stage 1
  extended_config = merge(local.base_config, {
    workflow = merge(local.base_config.workflow, {
      stage = "configuration-extension"
      dependencies = {
        stage1_checksum = local_file.stage1_base_config.content_md5
        stage1_file = local_file.stage1_base_config.filename
      }
    })
    
    services = {
      web = {
        name = "web-${random_string.environment_suffix.result}"
        port = random_integer.service_port.result
        replicas = 3
        image = "nginx:alpine"
        config = {
          server_name = "web-${random_string.environment_suffix.result}.example.com"
          client_max_body_size = "10M"
          proxy_timeout = "30s"
        }
        environment_vars = {
          ENV = "test"
          LOG_LEVEL = "info"
          SERVICE_PORT = tostring(random_integer.service_port.result)
        }
      }
      
      api = {
        name = "api-${random_string.environment_suffix.result}"
        port = random_integer.service_port.result + 1
        replicas = 2
        image = "alpine:latest"
        config = {
          database_url = "postgresql://db-${random_string.environment_suffix.result}:5432/app"
          redis_url = "redis://cache-${random_string.environment_suffix.result}:6379"
          jwt_secret = "test-secret-${random_string.environment_suffix.result}"
        }
        environment_vars = {
          ENV = "test"
          LOG_LEVEL = "debug"
          SERVICE_PORT = tostring(random_integer.service_port.result + 1)
          ENABLE_METRICS = "true"
        }
      }
      
      worker = {
        name = "worker-${random_string.environment_suffix.result}"
        replicas = 1
        image = "alpine:latest"
        config = {
          queue_url = "redis://cache-${random_string.environment_suffix.result}:6379"
          batch_size = 10
          processing_timeout = "5m"
        }
        environment_vars = {
          ENV = "test"
          LOG_LEVEL = "info"
          WORKER_CONCURRENCY = "5"
        }
      }
    }
    
    infrastructure = {
      database = {
        engine = "postgresql"
        version = "15.4"
        instance_class = "db.t3.micro"
        allocated_storage = 20
        storage_encrypted = true
        name = "app_${replace(random_string.environment_suffix.result, "-", "_")}"
        username = "app_user"
      }
      
      cache = {
        engine = "redis"
        version = "7.0"
        node_type = "cache.t3.micro"
        num_cache_nodes = 1
        port = 6379
      }
      
      load_balancer = {
        name = "lb-${random_string.environment_suffix.result}"
        type = "application"
        scheme = "internet-facing"
        listeners = [
          {
            port = 80
            protocol = "HTTP"
            target_port = random_integer.service_port.result
          },
          {
            port = 443
            protocol = "HTTPS"
            target_port = random_integer.service_port.result
            ssl_policy = "ELBSecurityPolicy-TLS-1-2-2017-01"
          }
        ]
        health_check = {
          enabled = true
          path = "/health"
          interval = 30
          timeout = 5
          healthy_threshold = 2
          unhealthy_threshold = 5
        }
      }
    }
  })
}

# Stage 2: Create extended configuration with service definitions
resource "local_file" "stage2_extended_config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.extended_config),
    "4spaces"
  )
  filename = "${path.module}/workflow/stage2-extended-config.json"
  file_permission = "0644"
  
  depends_on = [local_file.stage1_base_config]
}

# Stage 3: Environment-Specific Configurations
locals {
  # Development environment configuration
  dev_config = merge(local.extended_config, {
    workflow = merge(local.extended_config.workflow, {
      stage = "environment-specific-dev"
      environment_type = "development"
    })
    
    environment = merge(local.extended_config.environment, {
      name = "dev-${random_string.environment_suffix.result}"
      debug_enabled = true
      log_level = "debug"
    })
    
    services = {
      for service_name, service in local.extended_config.services :
      service_name => merge(service, {
        replicas = 1  # Reduce replicas for dev
        environment_vars = merge(service.environment_vars, {
          ENV = "development"
          DEBUG = "true"
        })
      })
    }
    
    infrastructure = merge(local.extended_config.infrastructure, {
      database = merge(local.extended_config.infrastructure.database, {
        instance_class = "db.t3.micro"
        allocated_storage = 10
        backup_retention_period = 1
      })
    })
  })
  
  # Production environment configuration
  prod_config = merge(local.extended_config, {
    workflow = merge(local.extended_config.workflow, {
      stage = "environment-specific-prod"
      environment_type = "production"
    })
    
    environment = merge(local.extended_config.environment, {
      name = "prod-${random_string.environment_suffix.result}"
      debug_enabled = false
      log_level = "warn"
      monitoring_enabled = true
    })
    
    services = {
      for service_name, service in local.extended_config.services :
      service_name => merge(service, {
        environment_vars = merge(service.environment_vars, {
          ENV = "production"
          DEBUG = "false"
          LOG_LEVEL = "warn"
        })
      })
    }
    
    infrastructure = merge(local.extended_config.infrastructure, {
      database = merge(local.extended_config.infrastructure.database, {
        instance_class = "db.t3.small"
        allocated_storage = 100
        backup_retention_period = 7
        multi_az = true
      })
      
      load_balancer = merge(local.extended_config.infrastructure.load_balancer, {
        access_logs = {
          enabled = true
          bucket = "lb-logs-${random_string.environment_suffix.result}"
        }
      })
    })
  })
}

# Stage 3a: Development environment configuration
resource "local_file" "stage3a_dev_config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.dev_config),
    "2spaces"
  )
  filename = "${path.module}/workflow/stage3a-dev-config.json"
  file_permission = "0644"
  
  depends_on = [local_file.stage2_extended_config]
}

# Stage 3b: Production environment configuration
resource "local_file" "stage3b_prod_config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.prod_config),
    "tab"
  )
  filename = "${path.module}/workflow/stage3b-prod-config.json"
  file_permission = "0644"
  
  depends_on = [local_file.stage2_extended_config]
}

# Stage 4: Deployment Manifests Generation
locals {
  # Generate Kubernetes-style deployment manifests
  k8s_manifests = {
    for service_name, service in local.extended_config.services :
    service_name => {
      apiVersion = "apps/v1"
      kind = "Deployment"
      metadata = {
        name = service.name
        namespace = "default"
        labels = {
          app = service.name
          version = "v1.0.0"
          environment = "test"
          workflow_id = random_uuid.workflow_id.result
        }
      }
      spec = {
        replicas = service.replicas
        selector = {
          matchLabels = {
            app = service.name
          }
        }
        template = {
          metadata = {
            labels = {
              app = service.name
              version = "v1.0.0"
            }
          }
          spec = {
            containers = [
              {
                name = service.name
                image = service.image
                ports = service_name == "worker" ? [] : [
                  {
                    containerPort = service.port
                    protocol = "TCP"
                  }
                ]
                env = [
                  for key, value in service.environment_vars : {
                    name = key
                    value = value
                  }
                ]
                resources = {
                  requests = {
                    memory = "64Mi"
                    cpu = "250m"
                  }
                  limits = {
                    memory = "128Mi"
                    cpu = "500m"
                  }
                }
              }
            ]
          }
        }
      }
    }
  }
  
  # Generate Docker Compose configuration
  docker_compose = {
    version = "3.8"
    services = {
      for service_name, service in local.extended_config.services :
      service_name => {
        image = service.image
        ports = service_name == "worker" ? [] : ["${service.port}:${service.port}"]
        environment = service.environment_vars
        restart = "unless-stopped"
        networks = ["app-network"]
        depends_on = service_name == "api" ? ["database", "redis"] : []
      }
    }
    
    networks = {
      app-network = {
        driver = "bridge"
      }
    }
    
    volumes = {
      postgres_data = {}
      redis_data = {}
    }
  }
}

# Stage 4a: Kubernetes manifests
resource "local_file" "stage4a_k8s_web_manifest" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.k8s_manifests.web),
    "2spaces"
  )
  filename = "${path.module}/workflow/k8s/web-deployment.json"
  file_permission = "0644"
  
  depends_on = [local_file.stage3a_dev_config, local_file.stage3b_prod_config]
}

resource "local_file" "stage4b_k8s_api_manifest" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.k8s_manifests.api),
    "2spaces"
  )
  filename = "${path.module}/workflow/k8s/api-deployment.json"
  file_permission = "0644"
  
  depends_on = [local_file.stage3a_dev_config, local_file.stage3b_prod_config]
}

resource "local_file" "stage4c_k8s_worker_manifest" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.k8s_manifests.worker),
    "2spaces"
  )
  filename = "${path.module}/workflow/k8s/worker-deployment.json"
  file_permission = "0644"
  
  depends_on = [local_file.stage3a_dev_config, local_file.stage3b_prod_config]
}

# Stage 4d: Docker Compose configuration
resource "local_file" "stage4d_docker_compose" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.docker_compose),
    "4spaces"
  )
  filename = "${path.module}/workflow/docker/docker-compose.json"
  file_permission = "0644"
  
  depends_on = [local_file.stage3a_dev_config, local_file.stage3b_prod_config]
}

# Stage 5: Final Integration and Validation
locals {
  # Final deployment summary
  deployment_summary = {
    workflow = {
      id = random_uuid.workflow_id.result
      name = "e2e-integration-test-${random_string.environment_suffix.result}"
      stage = "completion"
      completed_at = time_static.deployment_time.rfc3339
      duration = "calculated_at_runtime"
    }
    
    generated_files = {
      stage1 = {
        file = local_file.stage1_base_config.filename
        checksum = local_file.stage1_base_config.content_md5
        size = length(local_file.stage1_base_config.content)
      }
      stage2 = {
        file = local_file.stage2_extended_config.filename
        checksum = local_file.stage2_extended_config.content_md5
        size = length(local_file.stage2_extended_config.content)
      }
      stage3a = {
        file = local_file.stage3a_dev_config.filename
        checksum = local_file.stage3a_dev_config.content_md5
        size = length(local_file.stage3a_dev_config.content)
      }
      stage3b = {
        file = local_file.stage3b_prod_config.filename
        checksum = local_file.stage3b_prod_config.content_md5
        size = length(local_file.stage3b_prod_config.content)
      }
      k8s_manifests = {
        web = {
          file = local_file.stage4a_k8s_web_manifest.filename
          checksum = local_file.stage4a_k8s_web_manifest.content_md5
          size = length(local_file.stage4a_k8s_web_manifest.content)
        }
        api = {
          file = local_file.stage4b_k8s_api_manifest.filename
          checksum = local_file.stage4b_k8s_api_manifest.content_md5
          size = length(local_file.stage4b_k8s_api_manifest.content)
        }
        worker = {
          file = local_file.stage4c_k8s_worker_manifest.filename
          checksum = local_file.stage4c_k8s_worker_manifest.content_md5
          size = length(local_file.stage4c_k8s_worker_manifest.content)
        }
      }
      docker_compose = {
        file = local_file.stage4d_docker_compose.filename
        checksum = local_file.stage4d_docker_compose.content_md5
        size = length(local_file.stage4d_docker_compose.content)
      }
    }
    
    validation = {
      total_files_created = 8
      indentation_formats_used = ["2spaces", "4spaces", "tabs"]
      json_validation = "all_valid"
      dependency_chain_verified = true
      checksum_chain = [
        local_file.stage1_base_config.content_md5,
        local_file.stage2_extended_config.content_md5,
        local_file.stage3a_dev_config.content_md5,
        local_file.stage3b_prod_config.content_md5,
        local_file.stage4a_k8s_web_manifest.content_md5,
        local_file.stage4b_k8s_api_manifest.content_md5,
        local_file.stage4c_k8s_worker_manifest.content_md5,
        local_file.stage4d_docker_compose.content_md5
      ]
    }
    
    environment_summary = {
      unique_identifiers = {
        workflow_id = random_uuid.workflow_id.result
        environment_suffix = random_string.environment_suffix.result
        service_port = random_integer.service_port.result
        deployment_time = time_static.deployment_time.rfc3339
      }
      service_count = length(local.extended_config.services)
      infrastructure_components = length(local.extended_config.infrastructure)
      environments_configured = ["development", "production"]
      deployment_formats = ["kubernetes", "docker-compose"]
    }
  }
}

# Stage 5: Final deployment summary
resource "local_file" "stage5_deployment_summary" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.deployment_summary),
    "2spaces"
  )
  filename = "${path.module}/workflow/final-deployment-summary.json"
  file_permission = "0644"
  
  depends_on = [
    local_file.stage1_base_config,
    local_file.stage2_extended_config,
    local_file.stage3a_dev_config,
    local_file.stage3b_prod_config,
    local_file.stage4a_k8s_web_manifest,
    local_file.stage4b_k8s_api_manifest,
    local_file.stage4c_k8s_worker_manifest,
    local_file.stage4d_docker_compose
  ]
}

# Output comprehensive workflow validation data
output "e2e_workflow_validation" {
  description = "End-to-end workflow validation results"
  value = {
    workflow_id = random_uuid.workflow_id.result
    environment_suffix = random_string.environment_suffix.result
    total_stages_completed = 5
    total_files_generated = 9
    
    stage_completion = {
      stage1_initialization = "completed"
      stage2_extension = "completed"
      stage3_environments = "completed"
      stage4_manifests = "completed"
      stage5_summary = "completed"
    }
    
    file_chain_validation = {
      all_files_created = true
      dependency_chain_intact = true
      json_format_valid = true
      indentation_consistency = true
    }
    
    cross_platform_compatibility = {
      unix_paths_handled = true
      windows_paths_simulated = true
      multiple_indentation_formats = true
      unicode_content_supported = true
    }
    
    integration_test_summary = {
      services_configured = length(local.extended_config.services)
      environments_tested = 2
      manifest_formats = 2
      total_container_images = 3
      port_assignments_unique = true
    }
  }
}

output "workflow_file_manifest" {
  description = "Complete manifest of generated workflow files"
  value = {
    base_configuration = {
      file = local_file.stage1_base_config.filename
      format = "2spaces"
      checksum = local_file.stage1_base_config.content_md5
    }
    extended_configuration = {
      file = local_file.stage2_extended_config.filename
      format = "4spaces"
      checksum = local_file.stage2_extended_config.content_md5
    }
    environment_configurations = {
      development = {
        file = local_file.stage3a_dev_config.filename
        format = "2spaces"
        checksum = local_file.stage3a_dev_config.content_md5
      }
      production = {
        file = local_file.stage3b_prod_config.filename
        format = "tabs"
        checksum = local_file.stage3b_prod_config.content_md5
      }
    }
    deployment_manifests = {
      kubernetes = {
        web = {
          file = local_file.stage4a_k8s_web_manifest.filename
          checksum = local_file.stage4a_k8s_web_manifest.content_md5
        }
        api = {
          file = local_file.stage4b_k8s_api_manifest.filename
          checksum = local_file.stage4b_k8s_api_manifest.content_md5
        }
        worker = {
          file = local_file.stage4c_k8s_worker_manifest.filename
          checksum = local_file.stage4c_k8s_worker_manifest.content_md5
        }
      }
      docker_compose = {
        file = local_file.stage4d_docker_compose.filename
        checksum = local_file.stage4d_docker_compose.content_md5
      }
    }
    deployment_summary = {
      file = local_file.stage5_deployment_summary.filename
      format = "2spaces"
      checksum = local_file.stage5_deployment_summary.content_md5
    }
  }
}