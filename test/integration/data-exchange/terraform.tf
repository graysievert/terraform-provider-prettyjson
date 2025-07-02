# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {
  required_providers {
    prettyjson = {
      source = "graysievert/prettyjson"
    }
  }
}

provider "prettyjson" {
  # Provider configuration block
}