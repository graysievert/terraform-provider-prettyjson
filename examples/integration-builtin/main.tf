terraform {
  required_providers {
    prettyjson = {
      source = "local/prettyjson"
    }
  }
}

# Complex integration test data
locals {
  microservices_config = {
    deployment_id = "deploy-${formatdate("YYYYMMDD-hhmmss", timestamp())}"
    environment   = "testing"
    services = {
      frontend = {
        name     = "webapp-${substr(uuid(), 0, 8)}"
        replicas = 3
        ports    = [80, 443]
        config = {
          api_endpoint = "https://api.example.com"
          features = {
            auth_enabled      = true
            caching_enabled   = true
            analytics_enabled = true
          }
        }
      }
      backend = {
        name     = "api-${substr(uuid(), 0, 8)}"
        replicas = 2
        ports    = [8080, 9090]
        config = {
          database_url = "postgresql://db:5432/main"
          redis_url    = "redis://cache:6379"
          limits = {
            max_connections = 100
            timeout_seconds = 30
            rate_limit_rpm  = 1000
          }
        }
      }
    }
    infrastructure = {
      region         = "us-west-2"
      instance_types = ["t3.medium", "t3.large"]
      storage = {
        type = "gp3"
        size = "100"
        iops = 3000
      }
    }
  }

  k8s_config = {
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "app-config-${substr(uuid(), 0, 8)}"
      namespace = "default"
      labels = {
        app        = "web-service"
        version    = "v1.0.0"
        managed_by = "terraform"
      }
    }
    data = {
      "config.json" = jsonencode({
        server = {
          port = 8080
          host = "0.0.0.0"
        }
        database = {
          host     = "postgres.default.svc.cluster.local"
          port     = 5432
          database = "webapp"
        }
        features = {
          auth_required = true
          logging_level = "info"
          metrics_port  = 9090
        }
      })
    }
  }

  # Format configurations with different indentation
  microservices_dev = provider::prettyjson::jsonprettyprint(
    jsonencode(merge(local.microservices_config, {
      environment = "development"
      services = {
        for service_name, service in local.microservices_config.services :
        service_name => merge(service, {
          replicas = 1 # Reduce replicas for dev
          config = merge(service.config, {
            debug_mode = true
          })
        })
      }
    })),
    "2spaces"
  )

  microservices_prod = provider::prettyjson::jsonprettyprint(
    jsonencode(local.microservices_config),
    "4spaces"
  )

  k8s_configmap = provider::prettyjson::jsonprettyprint(
    jsonencode(local.k8s_config),
    "2spaces"
  )

  dynamic_config = provider::prettyjson::jsonprettyprint(
    jsonencode({
      generated_at = timestamp()
      deployment = {
        id = local.microservices_config.deployment_id
      }
      endpoints = {
        frontend = "https://${local.microservices_config.services.frontend.name}.example.com"
        api      = "https://${local.microservices_config.services.backend.name}.example.com"
      }
    }),
    "tab"
  )
}

# Create configuration files using terraform_data
resource "terraform_data" "create_configs_dir" {
  provisioner "local-exec" {
    command = "mkdir -p configs k8s formats metadata"
  }
}

resource "terraform_data" "write_microservices_dev" {
  triggers_replace = [local.microservices_dev]

  provisioner "local-exec" {
    command = <<-EOT
      cat > configs/microservices-dev.json << 'EOF'
${local.microservices_dev}
EOF
    EOT
  }

  depends_on = [terraform_data.create_configs_dir]
}

resource "terraform_data" "write_microservices_prod" {
  triggers_replace = [local.microservices_prod]

  provisioner "local-exec" {
    command = <<-EOT
      cat > configs/microservices-prod.json << 'EOF'
${local.microservices_prod}
EOF
    EOT
  }

  depends_on = [terraform_data.create_configs_dir]
}

resource "terraform_data" "write_k8s_configmap" {
  triggers_replace = [local.k8s_configmap]

  provisioner "local-exec" {
    command = <<-EOT
      cat > k8s/configmap.json << 'EOF'
${local.k8s_configmap}
EOF
    EOT
  }

  depends_on = [terraform_data.create_configs_dir]
}

resource "terraform_data" "write_dynamic_config" {
  triggers_replace = [local.dynamic_config]

  provisioner "local-exec" {
    command = <<-EOT
      cat > configs/dynamic-config.json << 'EOF'
${local.dynamic_config}
EOF
    EOT
  }

  depends_on = [terraform_data.create_configs_dir]
}

# Multiple format examples
resource "terraform_data" "write_multi_formats" {
  triggers_replace = [local.k8s_configmap]

  provisioner "local-exec" {
    command = <<-EOT
      # 2spaces format
      cat > formats/config-2spaces.json << 'EOF'
${provider::prettyjson::jsonprettyprint(jsonencode(local.k8s_config), "2spaces")}
EOF
      
      # 4spaces format  
      cat > formats/config-4spaces.json << 'EOF'
${provider::prettyjson::jsonprettyprint(jsonencode(local.k8s_config), "4spaces")}
EOF
      
      # tabs format
      cat > formats/config-tabs.json << 'EOF'
${provider::prettyjson::jsonprettyprint(jsonencode(local.k8s_config), "tab")}
EOF
    EOT
  }

  depends_on = [terraform_data.create_configs_dir]
}

# Verification and validation
resource "terraform_data" "validate_integration" {
  triggers_replace = [
    terraform_data.write_microservices_dev.id,
    terraform_data.write_microservices_prod.id,
    terraform_data.write_k8s_configmap.id,
    terraform_data.write_dynamic_config.id,
    terraform_data.write_multi_formats.id
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Integration Test Validation ==="
      echo "Files created:"
      find . -name "*.json" -type f | sort
      echo ""
      echo "File sizes:"
      find . -name "*.json" -type f -exec sh -c 'echo "{}: $(wc -c < "{}")"' \;
      echo ""
      echo "JSON validation:"
      if command -v jq >/dev/null 2>&1; then
        find . -name "*.json" -type f -exec sh -c 'echo "{}: $(jq empty "{}" 2>/dev/null && echo "VALID" || echo "INVALID")"' \;
      else
        echo "jq not available for JSON validation"
      fi
      echo ""
      echo "Indentation verification:"
      if [ -f "formats/config-2spaces.json" ]; then
        echo "2spaces sample (first 3 lines):"
        head -n 3 formats/config-2spaces.json | cat -A
      fi
      if [ -f "formats/config-4spaces.json" ]; then
        echo "4spaces sample (first 3 lines):" 
        head -n 3 formats/config-4spaces.json | cat -A
      fi
      if [ -f "formats/config-tabs.json" ]; then
        echo "tabs sample (first 3 lines):"
        head -n 3 formats/config-tabs.json | cat -A
      fi
    EOT
  }

  depends_on = [
    terraform_data.write_microservices_dev,
    terraform_data.write_microservices_prod,
    terraform_data.write_k8s_configmap,
    terraform_data.write_dynamic_config,
    terraform_data.write_multi_formats
  ]
}

# Outputs
output "integration_summary" {
  description = "Summary of integration test results"
  value = {
    configurations_created = [
      "configs/microservices-dev.json",
      "configs/microservices-prod.json",
      "configs/dynamic-config.json",
      "k8s/configmap.json",
      "formats/config-2spaces.json",
      "formats/config-4spaces.json",
      "formats/config-tabs.json"
    ]
    indentation_formats = ["2spaces", "4spaces", "tabs"]
    use_cases = [
      "microservices deployment",
      "kubernetes configuration",
      "dynamic configuration generation",
      "multi-format output"
    ]
  }
}

output "sample_configs" {
  description = "Sample configuration previews"
  value = {
    microservices_dev_preview  = substr(local.microservices_dev, 0, 200)
    microservices_prod_preview = substr(local.microservices_prod, 0, 200)
    k8s_config_preview         = substr(local.k8s_configmap, 0, 200)
    dynamic_config_preview     = substr(local.dynamic_config, 0, 200)
  }
}