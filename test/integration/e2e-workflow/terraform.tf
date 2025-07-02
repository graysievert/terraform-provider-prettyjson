# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {
  required_providers {
    prettyjson = {
      source = "graysievert/prettyjson"
    }
    local = {
      source = "hashicorp/local"
      version = "~> 2.4"
    }
    random = {
      source = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

provider "prettyjson" {
  # Provider configuration block
}