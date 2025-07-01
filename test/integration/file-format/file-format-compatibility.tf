# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# File format compatibility test suite
# This configuration tests file output compatibility across different platforms

# File format compatibility configuration is defined in terraform.tf

# Generate unique test identifiers
resource "random_string" "test_id" {
  length = 8
  special = false
  upper = false
}

locals {
  # Configuration data for file format testing
  config_data = {
    test_metadata = {
      test_id = random_string.test_id.result
      generated_at = timestamp()
      test_type = "file-format-compatibility"
      platform = "multi-platform"
    }
    
    # Application configuration with various data types
    application = {
      name = "file-format-test-${random_string.test_id.result}"
      version = "1.0.0"
      description = "Testing file format compatibility across platforms"
      
      server = {
        host = "localhost"
        port = 8080
        ssl = {
          enabled = true
          cert_path = "/etc/ssl/certs/app.crt"
          key_path = "/etc/ssl/private/app.key"
        }
        timeouts = {
          read = 30
          write = 30
          idle = 60
        }
      }
      
      database = {
        driver = "postgresql"
        host = "db.example.com"
        port = 5432
        name = "app_${random_string.test_id.result}"
        ssl_mode = "require"
        pool = {
          min_connections = 5
          max_connections = 20
          idle_timeout = "5m"
        }
      }
      
      features = {
        authentication = true
        authorization = true
        logging = {
          level = "info"
          format = "json"
          outputs = ["stdout", "file"]
          file_path = "/var/log/app/app.log"
        }
        metrics = {
          enabled = true
          endpoint = "/metrics"
          interval = "30s"
        }
        caching = {
          enabled = true
          ttl = 3600
          max_size = "100MB"
        }
      }
      
      # Environment-specific overrides
      environments = {
        development = {
          debug = true
          hot_reload = true
          database_name = "app_dev_${random_string.test_id.result}"
        }
        staging = {
          debug = false
          performance_monitoring = true
          database_name = "app_staging_${random_string.test_id.result}"
        }
        production = {
          debug = false
          performance_monitoring = true
          security_enhanced = true
          database_name = "app_prod_${random_string.test_id.result}"
        }
      }
    }
    
    # Infrastructure configuration
    infrastructure = {
      cloud_provider = "multi-cloud"
      regions = ["us-east-1", "us-west-2", "eu-west-1"]
      
      compute = {
        instance_type = "t3.medium"
        min_instances = 2
        max_instances = 10
        scaling_policy = {
          cpu_threshold = 70
          memory_threshold = 80
          scale_up_cooldown = "5m"
          scale_down_cooldown = "10m"
        }
      }
      
      storage = {
        type = "ssd"
        size = "100GB"
        backup_enabled = true
        backup_retention = "30d"
        encryption = {
          enabled = true
          key_rotation = true
        }
      }
      
      networking = {
        vpc_cidr = "10.0.0.0/16"
        subnets = [
          { name = "public-1", cidr = "10.0.1.0/24", zone = "a" },
          { name = "public-2", cidr = "10.0.2.0/24", zone = "b" },
          { name = "private-1", cidr = "10.0.3.0/24", zone = "a" },
          { name = "private-2", cidr = "10.0.4.0/24", zone = "b" }
        ]
        load_balancer = {
          type = "application"
          scheme = "internet-facing"
          health_check = {
            path = "/health"
            interval = 30
            timeout = 5
            retries = 3
          }
        }
      }
    }
  }
}

# Test file outputs with different indentation formats

# 2-space indentation files
resource "local_file" "config_2spaces_unix" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.config_data),
    "2spaces"
  )
  filename = "${path.module}/outputs/config-2spaces-unix.json"
  file_permission = "0644"
}

resource "local_file" "app_config_2spaces" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.config_data.application),
    "2spaces"
  )
  filename = "${path.module}/outputs/app-config-2spaces.json"
  file_permission = "0644"
}

resource "local_file" "infra_config_2spaces" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.config_data.infrastructure),
    "2spaces"
  )
  filename = "${path.module}/outputs/infra-config-2spaces.json"
  file_permission = "0644"
}

# 4-space indentation files
resource "local_file" "config_4spaces_unix" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.config_data),
    "4spaces"
  )
  filename = "${path.module}/outputs/config-4spaces-unix.json"
  file_permission = "0644"
}

resource "local_file" "app_config_4spaces" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.config_data.application),
    "4spaces"
  )
  filename = "${path.module}/outputs/app-config-4spaces.json"
  file_permission = "0644"
}

resource "local_file" "infra_config_4spaces" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.config_data.infrastructure),
    "4spaces"
  )
  filename = "${path.module}/outputs/infra-config-4spaces.json"
  file_permission = "0644"
}

# Tab indentation files
resource "local_file" "config_tabs_unix" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.config_data),
    "tab"
  )
  filename = "${path.module}/outputs/config-tabs-unix.json"
  file_permission = "0644"
}

resource "local_file" "app_config_tabs" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.config_data.application),
    "tab"
  )
  filename = "${path.module}/outputs/app-config-tabs.json"
  file_permission = "0644"
}

resource "local_file" "infra_config_tabs" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode(local.config_data.infrastructure),
    "tab"
  )
  filename = "${path.module}/outputs/infra-config-tabs.json"
  file_permission = "0644"
}

# Platform-specific path testing (simulated)
resource "local_file" "windows_style_paths" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      paths = {
        config_dir = "C:\\ProgramData\\App\\config"
        log_dir = "C:\\Logs\\App"
        data_dir = "C:\\Data\\App\\${random_string.test_id.result}"
        temp_dir = "C:\\Temp\\App"
      }
      settings = {
        file_separator = "\\"
        line_ending = "\\r\\n"
        case_sensitive = false
      }
    }),
    "2spaces"
  )
  filename = "${path.module}/outputs/windows-paths.json"
  file_permission = "0644"
}

resource "local_file" "unix_style_paths" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      paths = {
        config_dir = "/etc/app"
        log_dir = "/var/log/app"
        data_dir = "/var/lib/app/${random_string.test_id.result}"
        temp_dir = "/tmp/app"
      }
      settings = {
        file_separator = "/"
        line_ending = "\\n"
        case_sensitive = true
      }
    }),
    "2spaces"
  )
  filename = "${path.module}/outputs/unix-paths.json"
  file_permission = "0644"
}

# Test different file sizes and complexity
resource "local_file" "large_config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      large_array = [for i in range(100) : {
        id = i
        name = "item-${i}"
        value = i * 10
        metadata = {
          created_at = "2024-01-01T00:00:00Z"
          updated_at = "2024-01-01T00:00:00Z"
          tags = ["tag-${i}", "category-${i % 5}"]
        }
      }]
      large_object = {for i in range(50) : "key-${i}" => {
        nested_value = "value-${i}"
        nested_array = [for j in range(5) : "item-${i}-${j}"]
        nested_object = {
          deep_key = "deep-value-${i}"
          deep_array = [i, i*2, i*3]
        }
      }}
    }),
    "2spaces"
  )
  filename = "${path.module}/outputs/large-config.json"
  file_permission = "0644"
}

# Minimal configuration for testing
resource "local_file" "minimal_config" {
  content = provider::prettyjson::jsonprettyprint(
    jsonencode({
      app = "minimal-test"
      version = "1.0.0"
      enabled = true
    }),
    "2spaces"
  )
  filename = "${path.module}/outputs/minimal-config.json"
  file_permission = "0644"
}

# Output validation data
output "file_validation_data" {
  description = "File validation metadata for compatibility testing"
  value = {
    test_id = random_string.test_id.result
    files_created = [
      local_file.config_2spaces_unix.filename,
      local_file.app_config_2spaces.filename,
      local_file.infra_config_2spaces.filename,
      local_file.config_4spaces_unix.filename,
      local_file.app_config_4spaces.filename,
      local_file.infra_config_4spaces.filename,
      local_file.config_tabs_unix.filename,
      local_file.app_config_tabs.filename,
      local_file.infra_config_tabs.filename,
      local_file.windows_style_paths.filename,
      local_file.unix_style_paths.filename,
      local_file.large_config.filename,
      local_file.minimal_config.filename
    ]
    file_checksums = {
      config_2spaces = local_file.config_2spaces_unix.content_md5
      config_4spaces = local_file.config_4spaces_unix.content_md5
      config_tabs = local_file.config_tabs_unix.content_md5
      app_2spaces = local_file.app_config_2spaces.content_md5
      app_4spaces = local_file.app_config_4spaces.content_md5
      app_tabs = local_file.app_config_tabs.content_md5
      infra_2spaces = local_file.infra_config_2spaces.content_md5
      infra_4spaces = local_file.infra_config_4spaces.content_md5
      infra_tabs = local_file.infra_config_tabs.content_md5
      windows_paths = local_file.windows_style_paths.content_md5
      unix_paths = local_file.unix_style_paths.content_md5
      large_config = local_file.large_config.content_md5
      minimal_config = local_file.minimal_config.content_md5
    }
    file_sizes = {
      config_2spaces = length(local_file.config_2spaces_unix.content)
      config_4spaces = length(local_file.config_4spaces_unix.content)
      config_tabs = length(local_file.config_tabs_unix.content)
      large_config = length(local_file.large_config.content)
      minimal_config = length(local_file.minimal_config.content)
    }
    indentation_formats = ["2spaces", "4spaces", "tabs"]
    total_files = 13
  }
}

output "cross_platform_validation" {
  description = "Cross-platform validation checksums"
  value = {
    # These should be identical across platforms for the same content
    content_identity_check = {
      same_data_2spaces = local_file.config_2spaces_unix.content_md5
      same_data_4spaces = local_file.config_4spaces_unix.content_md5
      same_data_tabs = local_file.config_tabs_unix.content_md5
    }
    # These should be different due to indentation
    indentation_differences = {
      spaces_2_vs_4 = local_file.config_2spaces_unix.content_md5 != local_file.config_4spaces_unix.content_md5
      spaces_vs_tabs = local_file.config_2spaces_unix.content_md5 != local_file.config_tabs_unix.content_md5
    }
    platform_specific = {
      windows_paths_checksum = local_file.windows_style_paths.content_md5
      unix_paths_checksum = local_file.unix_style_paths.content_md5
    }
  }
}