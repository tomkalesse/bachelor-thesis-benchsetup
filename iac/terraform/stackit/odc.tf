resource "stackit_security_group" "odc-sut" {
  project_id = var.project_id
  name       = "odc-sut"
  stateful   = true
}

resource "stackit_security_group_rule" "odc-sut-rule-1" {
  project_id        = var.project_id
  security_group_id = stackit_security_group.odc-sut.security_group_id
  direction         = "ingress"
  ether_type        = "IPv4"
  protocol = {
    name = "tcp"
  }
  port_range = {
    min = 22
    max = 22
  }
}

resource "stackit_security_group_rule" "odc-sut-rule-2" {
  project_id        = var.project_id
  security_group_id = stackit_security_group.odc-sut.security_group_id
  direction         = "ingress"
  ether_type        = "IPv4"
  protocol = {
    name = "tcp"
  }
  port_range = {
    min = 8080
    max = 8080
  }
}

resource "stackit_network_interface" "odc-sut" {
  project_id         = var.project_id
  network_id         = stackit_network.main.network_id
  security_group_ids = [stackit_security_group.odc-sut.security_group_id]
}

resource "stackit_public_ip" "odc-sut" {
  project_id           = var.project_id
  network_interface_id = stackit_network_interface.odc-sut.network_interface_id
  labels               = var.tags
}

resource "stackit_volume" "odc-sut" {
  project_id        = var.project_id
  name              = "odc-sut"
  availability_zone = "eu01-2"
  source = {
    type                  = "image"
    id                    = "5f204808-32b0-406c-9dbd-064a210b1495"
    delete_on_termination = true
  }
  size   = 256
  labels = var.tags
}

resource "stackit_server" "odc-sut" {
  project_id        = var.project_id
  name              = "odc-sut"
  availability_zone = "eu01-2"
  machine_type      = "g2i.4"
  boot_volume = {
    source_type = "volume"
    source_id   = stackit_volume.odc-sut.volume_id
  }
  keypair_name = stackit_key_pair.vm.name
  network_interfaces = [
    stackit_network_interface.odc-sut.network_interface_id
  ]
  labels = var.tags
}

resource "stackit_network_interface" "odc-client" {
  project_id         = var.project_id
  network_id         = stackit_network.main.network_id
  security_group_ids = [stackit_security_group.odc-sut.security_group_id]
}

resource "stackit_public_ip" "odc-client" {
  project_id           = var.project_id
  network_interface_id = stackit_network_interface.odc-client.network_interface_id
  labels               = var.tags
}

resource "stackit_volume" "odc-client" {
  project_id        = var.project_id
  name              = "odc-client"
  availability_zone = "eu01-2"
  source = {
    type                  = "image"
    id                    = "5f204808-32b0-406c-9dbd-064a210b1495"
    delete_on_termination = true
  }
  size   = 64
  labels = var.tags
}

resource "stackit_server" "odc-client" {
  project_id        = var.project_id
  name              = "odc-client"
  availability_zone = "eu01-2"
  machine_type      = "g2i.4"
  boot_volume = {
    source_type = "volume"
    source_id   = stackit_volume.odc-client.volume_id
  }
  keypair_name = stackit_key_pair.vm.name
  network_interfaces = [
    stackit_network_interface.odc-client.network_interface_id
  ]
  labels = var.tags
}

output "odc_sut_ip" {
  value = stackit_public_ip.odc-sut.ip
}

output "odc_client_ip" {
  value = stackit_public_ip.odc-client.ip
}