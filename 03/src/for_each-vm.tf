# for_each-vm.tf
variable "each_vm" {
  type = list(object({
    vm_name     = string
    cpu         = number
    ram         = number
    disk_volume = number
  }))
  default = [
    { vm_name = "main",    cpu = 2, ram = 2, disk_volume = 9 },
    { vm_name = "replica", cpu = 2, ram = 2, disk_volume = 9 },
  ]
}

resource "yandex_compute_instance" "db" {
  for_each   = { for vm in var.each_vm : vm.vm_name => vm }
  name       = each.value.vm_name
  folder_id  = var.folder_id
  zone       = var.default_zone
  platform_id = "standard-v1"

  resources {
    cores  = each.value.cpu
    memory = each.value.ram
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = each.value.disk_volume
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.develop.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.example.id]
  }

  allow_stopping_for_update = true

  metadata = {
    ssh-keys = file("~/.ssh/id_rsa.pub")
  }
}
