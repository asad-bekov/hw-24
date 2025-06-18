# создаём 3 диска
resource "yandex_compute_disk" "additional" {
  count = 3
  name  = format("storage-disk-%d", count.index + 1)
  zone  = var.default_zone

  type = "network-hdd"
  size = 1
}

resource "yandex_compute_instance" "storage" {
  name        = "storage"
  folder_id   = var.folder_id
  zone        = var.default_zone
  platform_id = "standard-v1"

  resources {
    cores  = 2
    memory = 2
  }


  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 9
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.develop.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.example.id]
  }


  dynamic "secondary_disk" {
    for_each = yandex_compute_disk.additional
    content {
      disk_id     = secondary_disk.value.id
      device_name = secondary_disk.value.name
    }
  }

  allow_stopping_for_update = true

  metadata = {
    ssh-keys = file("~/.ssh/id_rsa.pub")
  }
}
