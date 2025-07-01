output "performance_metrics" {
  description = "Performance metrics and file size information"
  value = {
    large_config_size      = length(local_file.large_config_optimized.content)
    optimized_config_size  = length(local_file.optimized_config_compact.content)
    dev_config_size        = length(local_file.dev_config_minimal.content)
    monitoring_config_size = length(local_file.monitoring_only_config.content)

    size_reduction_percentage = round(
      (1 - (length(local_file.optimized_config_compact.content) / length(local_file.large_config_optimized.content))) * 100,
      2
    )

    performance_recommendations = {
      small_files  = "< 10KB - Use 2spaces, access frequently"
      medium_files = "10KB-100KB - Use 2spaces or 4spaces, moderate access"
      large_files  = "> 100KB - Use 4spaces or tabs, access infrequently"
    }
  }
}

output "file_locations" {
  description = "Generated configuration file locations organized by performance characteristics"
  value = {
    high_performance = {
      optimized_config = local_file.optimized_config_compact.filename
      dev_minimal      = local_file.dev_config_minimal.filename
      monitoring_only  = local_file.monitoring_only_config.filename
    }

    comprehensive = {
      large_config      = local_file.large_config_optimized.filename
      production_config = var.environment == "production" ? local_file.conditional_large_config[0].filename : "Not created (non-production environment)"
    }

    chunked_configs = {
      for k, v in local_file.service_chunks : k => v.filename
    }

    index_file = local_file.lazy_loading_index.filename
  }
}

output "optimization_strategies" {
  description = "Performance optimization strategies demonstrated"
  value = {
    "1_selective_data_inclusion" = {
      description = "Include only necessary data for specific use cases"
      example     = "Monitoring config excludes detailed service configuration"
      benefit     = "Reduces file size by 60-80% for specialized use cases"
    }

    "2_environment_specific_optimization" = {
      description = "Different configurations for different environments"
      example     = "Development uses only 5 services vs 50 in production"
      benefit     = "Faster development cycles, reduced resource usage"
    }

    "3_conditional_resource_creation" = {
      description = "Create expensive resources only when needed"
      example     = "Large config file only created in production environment"
      benefit     = "Reduces terraform plan/apply time in non-production"
    }

    "4_configuration_chunking" = {
      description = "Split large configurations into smaller chunks"
      example     = "50 services split into 5 chunks of 10 services each"
      benefit     = "Parallel processing, better memory usage, faster access"
    }

    "5_indentation_optimization" = {
      description = "Choose indentation based on file size and usage"
      example     = "2spaces for small files, 4spaces for large files, tabs for very large"
      benefit     = "Optimal balance between readability and file size"
    }

    "6_lazy_loading_pattern" = {
      description = "Use index files for on-demand configuration loading"
      example     = "Index file provides metadata about available configurations"
      benefit     = "Load only required configurations, reduces initial load time"
    }
  }
}

output "performance_benchmarks" {
  description = "Performance benchmarks and recommendations"
  value = {
    file_size_comparison = {
      full_config       = "${length(local_file.large_config_optimized.content)} bytes"
      optimized_config  = "${length(local_file.optimized_config_compact.content)} bytes"
      dev_config        = "${length(local_file.dev_config_minimal.content)} bytes"
      monitoring_config = "${length(local_file.monitoring_only_config.content)} bytes"
    }

    terraform_performance_tips = {
      plan_time    = "Use conditional resources to avoid planning unnecessary resources"
      apply_time   = "Chunk large configurations to enable parallel processing"
      state_size   = "Minimize state size by using computed values efficiently"
      memory_usage = "Split large data structures into smaller, manageable chunks"
    }

    json_formatting_performance = {
      "2spaces" = {
        use_case    = "Small to medium files (< 50KB)"
        performance = "Faster parsing, good compression"
        readability = "High"
      }
      "4spaces" = {
        use_case    = "Large files (50KB - 500KB)"
        performance = "Good balance of size and readability"
        readability = "Very high"
      }
      "tabs" = {
        use_case    = "Very large files (> 500KB)"
        performance = "Smallest file size, fastest parsing"
        readability = "Good (editor-dependent)"
      }
    }

    best_practices = {
      "frequent_access"   = "Use optimized, smaller configurations with 2-space indentation"
      "infrequent_access" = "Use comprehensive configurations with 4-space or tab indentation"
      "development"       = "Use minimal configurations with only necessary services"
      "production"        = "Use complete configurations with proper chunking for large datasets"
      "monitoring"        = "Use specialized configurations with only monitoring-relevant data"
    }
  }
}

output "chunk_information" {
  description = "Information about chunked configurations for performance optimization"
  value = {
    total_chunks = length(local_file.service_chunks)
    chunk_details = {
      for k, v in local_file.service_chunks : k => {
        filename          = v.filename
        size_bytes        = length(v.content)
        services_included = length(split(",", replace(replace(k, "chunk-", ""), "-", ",")))
      }
    }
    chunking_benefits = {
      parallel_processing = "Each chunk can be processed independently"
      memory_efficiency   = "Load only required chunks into memory"
      update_granularity  = "Update individual chunks without affecting others"
      scalability         = "Easy to add more chunks as data grows"
    }
  }
}

output "usage_recommendations" {
  description = "Specific usage recommendations based on performance analysis"
  value = {
    "small_teams_or_projects" = {
      recommendation = "Use optimized_config with 2spaces indentation"
      reason         = "Faster loading, easier to read and maintain"
    }

    "large_enterprise_deployments" = {
      recommendation = "Use chunked configurations with conditional creation"
      reason         = "Better performance, scalability, and maintenance"
    }

    "development_environments" = {
      recommendation = "Use dev_minimal_config with 2spaces indentation"
      reason         = "Faster development cycles, reduced resource usage"
    }

    "ci_cd_pipelines" = {
      recommendation = "Use monitoring_only_config and conditional creation"
      reason         = "Faster pipeline execution, reduced resource usage"
    }

    "monitoring_systems" = {
      recommendation = "Use monitoring_only_config with lazy loading"
      reason         = "Specialized data, faster access, reduced overhead"
    }
  }
}