output "deployment_info" {
  description = "Deployment information and generated file locations"
  value = {
    deployment_id = random_id.deployment_id.hex
    app_suffix    = random_string.app_suffix.result
    environment   = var.environment
  }
}

output "generated_files" {
  description = "Locations of all generated configuration files"
  value = {
    configs = {
      microservices_dev  = local_file.microservices_config_dev.filename
      microservices_prod = local_file.microservices_config_prod.filename
      dynamic_config     = local_file.dynamic_config.filename
    }
    kubernetes = {
      configmap = local_file.k8s_configmap.filename
    }
    formats = {
      config_2spaces = local_file.multi_format_2spaces.filename
      config_4spaces = local_file.multi_format_4spaces.filename
      config_tabs    = local_file.multi_format_tabs.filename
    }
    metadata = {
      deployment_metadata = local_file.computed_config.filename
    }
  }
}

output "file_checksums" {
  description = "MD5 checksums of generated files for validation"
  value = {
    microservices_dev  = local_file.microservices_config_dev.content_md5
    microservices_prod = local_file.microservices_config_prod.content_md5
    k8s_configmap      = local_file.k8s_configmap.content_md5
    dynamic_config     = local_file.dynamic_config.content_md5
    computed_config    = local_file.computed_config.content_md5
  }
}

output "integration_examples" {
  description = "Examples of how prettyjson provider integrates with other resources"
  value = {
    "random_integration" = {
      description = "Using random provider outputs in prettyjson formatting"
      example = {
        deployment_id = random_id.deployment_id.hex
        app_suffix    = random_string.app_suffix.result
      }
    }
    "local_file_integration" = {
      description = "Creating multiple formatted files with different indentation"
      formats     = ["2spaces", "4spaces", "tabs"]
    }
    "computed_values" = {
      description = "Using computed values from other resources in JSON formatting"
      example     = "See computed_config file for timestamp and checksum integration"
    }
    "dependency_management" = {
      description = "Proper dependency ordering for multi-resource configurations"
      pattern     = "Use depends_on for files that reference other resource outputs"
    }
  }
}

output "usage_patterns" {
  description = "Common usage patterns demonstrated in this example"
  value = {
    "multi_environment"   = "Different configurations for dev/prod environments"
    "kubernetes_configs"  = "Generating Kubernetes-compatible JSON configurations"
    "dynamic_generation"  = "Using Terraform functions and resources in JSON content"
    "format_consistency"  = "Maintaining consistent formatting across multiple files"
    "resource_references" = "Referencing other Terraform resources in JSON content"
  }
}

# Preview outputs showing formatted JSON content
output "sample_microservices_config" {
  description = "Preview of microservices configuration (first 500 characters)"
  value       = substr(local_file.microservices_config_prod.content, 0, 500)
}

output "sample_k8s_config" {
  description = "Preview of Kubernetes configuration (first 300 characters)"
  value       = substr(local_file.k8s_configmap.content, 0, 300)
}