locals {
  webservers = [
    for inst in yandex_compute_instance.web : {
      name         = inst.name
      fqdn         = inst.fqdn
      ansible_host = inst.network_interface[0].nat_ip_address != "" ? inst.network_interface[0].nat_ip_address : inst.network_interface[0].ip_address
    }
  ]

  databases = [
    for inst in values(yandex_compute_instance.db) : {
      name         = inst.name
      fqdn         = inst.fqdn
      ansible_host = inst.network_interface[0].nat_ip_address != "" ? inst.network_interface[0].nat_ip_address : inst.network_interface[0].ip_address
    }
  ]

  storage = [
    {
      name         = yandex_compute_instance.storage.name
      fqdn         = yandex_compute_instance.storage.fqdn
      ansible_host = yandex_compute_instance.storage.network_interface[0].nat_ip_address != "" ? yandex_compute_instance.storage.network_interface[0].nat_ip_address : yandex_compute_instance.storage.network_interface[0].ip_address
    }
  ]
}

resource "local_file" "ansible_inventory" {
  content  = templatefile("${path.module}/templates/inventory.tpl", {
    webservers = local.webservers
    databases  = local.databases
    storage    = local.storage
  })
  filename = "${path.module}/inventory.ini"
}

resource "null_resource" "run_playbook" {
  depends_on = [ local_file.ansible_inventory ]
  triggers = {
    inventory_sha = filesha256(local_file.ansible_inventory.filename)
  }
  provisioner "local-exec" {
    command     = "ansible-playbook -i inventory.ini playbook.yml"
    working_dir = path.module
  }
}
