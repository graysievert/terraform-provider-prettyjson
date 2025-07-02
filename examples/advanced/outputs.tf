# Outputs for Advanced Complex Data Structure Examples
# These outputs demonstrate how to work with complex nested data structures
# and showcase the prettyjson provider's capabilities with real-world configurations.

output "generated_configuration_files" {
  description = "Map of all generated configuration files with metadata"
  value = {
    microservices = {
      all_formats = {
        two_spaces  = local_file.microservices_config_2spaces.filename
        four_spaces = local_file.microservices_config_4spaces.filename
        tabs        = local_file.microservices_config_tabs.filename
      }
      individual_services = {
        for service_name, file in local_file.kubernetes_manifests : service_name => {
          filename   = file.filename
          size_bytes = length(file.content)
        }
      }
      processed_data = {
        for service_name, file in local_file.processed_service_data : service_name => {
          filename   = file.filename
          size_bytes = length(file.content)
        }
      }
    }
    infrastructure = {
      aws_config = {
        filename   = local_file.aws_infrastructure_config.filename
        size_bytes = length(local_file.aws_infrastructure_config.content)
      }
      deployment_matrix = {
        filename   = local_file.deployment_matrix.filename
        size_bytes = length(local_file.deployment_matrix.content)
      }
    }
    monitoring = {
      prometheus = {
        filename   = local_file.prometheus_config.filename
        size_bytes = length(local_file.prometheus_config.content)
      }
      grafana = {
        filename   = local_file.grafana_dashboards.filename
        size_bytes = length(local_file.grafana_dashboards.content)
      }
    }
    application_stack = {
      filename   = local_file.application_stack_config.filename
      size_bytes = length(local_file.application_stack_config.content)
    }
  }
}

output "data_structure_complexity_metrics" {
  description = "Metrics showing the complexity of processed data structures"
  value = {
    microservices = {
      total_services = length(var.microservices)
      total_ports = sum([
        for service in var.microservices : length(service.ports)
      ])
      total_environment_variables = sum([
        for service in var.microservices : length(service.env_vars)
      ])
      services_with_https = length([
        for service_name, service in var.microservices : service_name
        if contains(service.ports, 443) || contains(service.ports, 8443)
      ])
    }
    infrastructure = {
      total_subnets = length(var.infrastructure_config.vpc.subnets)
      public_subnets = length([
        for subnet in var.infrastructure_config.vpc.subnets : subnet if subnet.public
      ])
      private_subnets = length([
        for subnet in var.infrastructure_config.vpc.subnets : subnet if !subnet.public
      ])
      security_groups = length(var.infrastructure_config.security_groups)
      total_ingress_rules = sum([
        for sg in var.infrastructure_config.security_groups : length(sg.ingress_rules)
      ])
      total_egress_rules = sum([
        for sg in var.infrastructure_config.security_groups : length(sg.egress_rules)
      ])
      databases = length(var.infrastructure_config.databases)
    }
    generated_files = {
      total_files = 12 + length(var.microservices) * 2 # Base files + per-service files
      total_content_size = (
        length(local_file.microservices_config_2spaces.content) +
        length(local_file.microservices_config_4spaces.content) +
        length(local_file.microservices_config_tabs.content) +
        length(local_file.aws_infrastructure_config.content) +
        length(local_file.application_stack_config.content) +
        length(local_file.prometheus_config.content) +
        length(local_file.grafana_dashboards.content) +
        length(local_file.deployment_matrix.content) +
        sum([for file in local_file.kubernetes_manifests : length(file.content)]) +
        sum([for file in local_file.processed_service_data : length(file.content)])
      )
    }
  }
}

output "jsonencode_integration_examples" {
  description = "Examples of direct jsonencode() integration with prettyjson"
  value = {
    simple_object = provider::prettyjson::jsonprettyprint(
      jsonencode({
        message   = "Simple object example"
        timestamp = timestamp()
      }),
      "2spaces"
    )
    complex_nested = provider::prettyjson::jsonprettyprint(
      jsonencode({
        application = {
          name     = "complex-app"
          services = keys(var.microservices)
          config = {
            database = {
              enabled  = true
              replicas = 3
            }
            cache = {
              enabled = true
              ttl     = 3600
            }
          }
        }
        deployment = {
          environments = var.deployment_environments
          strategies   = ["blue-green", "rolling", "canary"]
        }
      }),
      "4spaces"
    )
    list_processing = provider::prettyjson::jsonprettyprint(
      jsonencode({
        services = [
          for service_name, config in var.microservices : {
            name              = service_name
            image             = config.image
            ports             = config.ports
            replicas          = config.replicas
            resource_requests = "${config.resources.requests.cpu}/${config.resources.requests.memory}"
          }
        ]
      }),
      "tab"
    )
  }
}

output "terraform_integration_metadata" {
  description = "Metadata about Terraform integration and provider usage"
  value = {
    providers_used = {
      prettyjson = "graysievert/prettyjson"
      local      = "hashicorp/local"
      random     = "hashicorp/random"
    }
    terraform_features = {
      workspace          = terraform.workspace
      version_constraint = ">= 1.8.0"
      functions_used = [
        "jsonencode",
        "provider::prettyjson::jsonprettyprint",
        "length",
        "contains",
        "timestamp",
        "keys",
        "sum"
      ]
    }
    advanced_patterns = {
      for_each_usage      = true
      conditional_logic   = true
      data_transformation = true
      nested_locals       = true
      complex_validation  = true
    }
    backup_suffix = random_id.backup_suffix.hex
  }
}

output "real_world_usage_examples" {
  description = "Real-world usage patterns and best practices demonstrated"
  value = {
    kubernetes_deployment_generation = {
      description     = "Generates Kubernetes deployment manifests from service configuration"
      files_generated = length(local_file.kubernetes_manifests)
      indentation     = "2spaces"
      use_case        = "CI/CD pipeline integration"
    }
    monitoring_configuration = {
      description        = "Generates monitoring tool configurations"
      prometheus_config  = local_file.prometheus_config.filename
      grafana_dashboards = local_file.grafana_dashboards.filename
      use_case           = "Observability stack deployment"
    }
    infrastructure_as_code = {
      description = "Complex AWS infrastructure configuration"
      file        = local_file.aws_infrastructure_config.filename
      components  = ["VPC", "Security Groups", "Databases"]
      use_case    = "Multi-tier application deployment"
    }
    deployment_matrix = {
      description  = "Environment-specific deployment configurations"
      file         = local_file.deployment_matrix.filename
      environments = var.deployment_environments
      use_case     = "Multi-environment CI/CD"
    }
  }
}

output "indentation_comparison" {
  description = "Comparison of different indentation styles with the same data"
  value = {
    sample_data = {
      original = var.microservices.api
      formatted = {
        two_spaces = provider::prettyjson::jsonprettyprint(
          jsonencode(var.microservices.api),
          "2spaces"
        )
        four_spaces = provider::prettyjson::jsonprettyprint(
          jsonencode(var.microservices.api),
          "4spaces"
        )
        tabs = provider::prettyjson::jsonprettyprint(
          jsonencode(var.microservices.api),
          "tab"
        )
      }
    }
    size_comparison = {
      two_spaces_size = length(provider::prettyjson::jsonprettyprint(
        jsonencode(var.microservices.api), "2spaces"
      ))
      four_spaces_size = length(provider::prettyjson::jsonprettyprint(
        jsonencode(var.microservices.api), "4spaces"
      ))
      tabs_size = length(provider::prettyjson::jsonprettyprint(
        jsonencode(var.microservices.api), "tab"
      ))
    }
  }
}