# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {
  required_providers {
    prettyjson = {
      source = "hashicorp/prettyjson"
      version = "~> 1.0"
    }
  }
}

provider "prettyjson" {
  # Provider configuration block
}