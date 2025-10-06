resource "stackit_security_group" "manager" {
  project_id = var.project_id
  name       = "manager"
  stateful   = true
}

resource "stackit_security_group_rule" "manager-rule-1" {
  project_id        = var.project_id
  security_group_id = stackit_security_group.manager.security_group_id
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

resource "stackit_network_interface" "manager" {
  project_id         = var.project_id
  network_id         = stackit_network.main.network_id
  security_group_ids = [stackit_security_group.manager.security_group_id]
}

resource "stackit_public_ip" "manager" {
  project_id           = var.project_id
  network_interface_id = stackit_network_interface.manager.network_interface_id
  labels               = var.tags
}

resource "stackit_volume" "manager" {
  project_id        = var.project_id
  name              = "manager"
  availability_zone = "eu01-2"
  source = {
    type                  = "image"
    id                    = "5f204808-32b0-406c-9dbd-064a210b1495"
    delete_on_termination = true
  }
  size   = 64
  labels = var.tags
}

resource "stackit_server" "manager" {
  project_id        = var.project_id
  name              = "manager"
  availability_zone = "eu01-2"
  machine_type      = "g2i.2"
  boot_volume = {
    source_type = "volume"
    source_id   = stackit_volume.manager.volume_id
  }
  keypair_name = stackit_key_pair.vm.name
  network_interfaces = [
    stackit_network_interface.manager.network_interface_id
  ]
  labels = var.tags
}

output "manager_ip" {
  value = stackit_public_ip.manager.ip
}
