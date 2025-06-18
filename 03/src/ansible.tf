locals {
  # Собираем список web‑VM
  webservers = [
    for inst in yandex_compute_instance.web :
    {
      name        = inst.name
      external_ip = inst.network_interface[0].nat_ip_address
      fqdn        = inst.fqdn
    }
  ]

  # Список БД‑VM
  databases = [
    for inst in yandex_compute_instance.db :
    {
      name        = inst.name
      external_ip = inst.network_interface[0].nat_ip_address
      fqdn        = inst.fqdn
    }
  ]

  # Список для storage (здесь ровно один элемент)
  storage = [
    {
      name        = yandex_compute_instance.storage.name
      external_ip = yandex_compute_instance.storage.network_interface[0].nat_ip_address
      fqdn        = yandex_compute_instance.storage.fqdn
    }
  ]
}

resource "local_file" "ansible_inventory" {
  # Генерируем содержимое из шаблона
  content  = templatefile("${path.module}/templates/inventory.tpl", {
    webservers = local.webservers
    databases  = local.databases
    storage    = local.storage
  })
  filename = "${path.module}/inventory.ini"
}
