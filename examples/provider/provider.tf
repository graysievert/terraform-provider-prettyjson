terraform {
  required_providers {
    prettyjson = {
      source = "hashicorp/prettyjson"
    }
    local = {
      source = "hashicorp/local"
    }
  }
  required_version = ">= 1.8.0"
}

provider "prettyjson" {
  # No configuration required for this function-only provider
}
