data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}
resource "yandex_compute_instance" "web" {
  count       = 2
  name        = format("web-%d", count.index + 1)
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
    nat                = true
    security_group_ids = [yandex_vpc_security_group.example.id]
  }

  scheduling_policy {
    preemptible = true
  }

  allow_stopping_for_update = true

  metadata = {
    ssh-keys = file("~/.ssh/id_rsa.pub")
  }

 # depends_on = [yandex_compute_instance.db_main]
}
