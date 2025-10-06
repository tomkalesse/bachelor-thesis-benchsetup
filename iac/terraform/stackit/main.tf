resource "stackit_network" "main" {
  project_id       = var.project_id
  name             = "main-network"
  ipv4_nameservers = ["8.8.8.8", "1.1.1.1"]
  labels           = var.tags
}

resource "stackit_key_pair" "vm" {
  name       = "vm-key-pair"
  public_key = file("~/.ssh/id_rsa.pub")
  labels     = var.tags
}

resource "local_file" "ansible_inventory" {
  content  = templatefile("../../ansible/inventory.tpl", {
    manager_ip = stackit_public_ip.manager.ip
    odc_sut_ip = stackit_public_ip.odc-sut.ip
    odc_client_ip = stackit_public_ip.odc-client.ip
    rasdaman_sut_ip = stackit_public_ip.rasdaman-sut.ip
    rasdaman_client_ip = stackit_public_ip.rasdaman-client.ip
  })
  filename = "../../ansible/inventory.ini"
}

resource "local_file" "hosts_yaml" {
  content  = templatefile("../../../manager/hosts.tpl", {
    odc_sut_ip = stackit_public_ip.odc-sut.ip
    odc_client_ip = stackit_public_ip.odc-client.ip
    rasdaman_sut_ip = stackit_public_ip.rasdaman-sut.ip
    rasdaman_client_ip = stackit_public_ip.rasdaman-client.ip
  })
  filename = "../../../manager/hosts.yml"
}

