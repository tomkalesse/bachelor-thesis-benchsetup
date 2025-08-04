terraform {
  required_providers {
    stackit = {
      source  = "stackitcloud/stackit"
      version = "0.56.0"
    }
  }
}

provider "stackit" {
  default_region           = "eu01"
  service_account_key_path = "./sa_key.json"
  private_key_path = "./sa-key-private.pem"
}
