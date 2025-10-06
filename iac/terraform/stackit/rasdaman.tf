resource "stackit_security_group" "rasdaman-sut" {
  project_id = var.project_id
  name       = "rasdaman-sut"
  stateful   = true
}

resource "stackit_security_group_rule" "rasdaman-sut-rule-1" {
  project_id        = var.project_id
  security_group_id = stackit_security_group.rasdaman-sut.security_group_id
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

resource "stackit_security_group_rule" "rasdaman-sut-rule-2" {
  project_id        = var.project_id
  security_group_id = stackit_security_group.rasdaman-sut.security_group_id
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

resource "stackit_network_interface" "rasdaman-sut" {
  project_id         = var.project_id
  network_id         = stackit_network.main.network_id
  security_group_ids = [stackit_security_group.rasdaman-sut.security_group_id]
}

resource "stackit_public_ip" "rasdaman-sut" {
  project_id           = var.project_id
  network_interface_id = stackit_network_interface.rasdaman-sut.network_interface_id
  labels               = var.tags
}

resource "stackit_volume" "rasdaman-sut" {
  project_id        = var.project_id
  name              = "rasdaman-sut"
  availability_zone = "eu01-2"
  source = {
    type                  = "image"
    id                    = "5f204808-32b0-406c-9dbd-064a210b1495"
    delete_on_termination = true
  }
  size   = 256
  labels = var.tags
}

resource "stackit_server" "rasdaman-sut" {
  project_id        = var.project_id
  name              = "rasdaman-sut"
  availability_zone = "eu01-2"
  machine_type      = "g2i.4"
  boot_volume = {
    source_type = "volume"
    source_id   = stackit_volume.rasdaman-sut.volume_id
  }
  keypair_name = stackit_key_pair.vm.name
  network_interfaces = [
    stackit_network_interface.rasdaman-sut.network_interface_id
  ]
  labels = var.tags
}

resource "stackit_network_interface" "rasdaman-client" {
  project_id         = var.project_id
  network_id         = stackit_network.main.network_id
  security_group_ids = [stackit_security_group.rasdaman-sut.security_group_id]
}

resource "stackit_public_ip" "rasdaman-client" {
  project_id           = var.project_id
  network_interface_id = stackit_network_interface.rasdaman-client.network_interface_id
  labels               = var.tags
}

resource "stackit_volume" "rasdaman-client" {
  project_id        = var.project_id
  name              = "rasdaman-client"
  availability_zone = "eu01-2"
  source = {
    type                  = "image"
    id                    = "5f204808-32b0-406c-9dbd-064a210b1495"
    delete_on_termination = true
  }
  size   = 64
  labels = var.tags
}

resource "stackit_server" "rasdaman-client" {
  project_id        = var.project_id
  name              = "rasdaman-client"
  availability_zone = "eu01-2"
  machine_type      = "g2i.4"
  boot_volume = {
    source_type = "volume"
    source_id   = stackit_volume.rasdaman-client.volume_id
  }
  keypair_name = stackit_key_pair.vm.name
  network_interfaces = [
    stackit_network_interface.rasdaman-client.network_interface_id
  ]
  labels = var.tags
}

output "rasdaman_sut_ip" {
  value = stackit_public_ip.rasdaman-sut.ip
}

output "rasdaman_client_ip" {
  value = stackit_public_ip.rasdaman-client.ip
}
