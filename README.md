# Домашнее задание "Управляющие конструкции в коде Terraform"

> **Репозиторий:** [hw-24](https://github.com/asad-bekov/hw-24/tree/terraform-03)\
> **Автор:** Асадбеков Асадбек\
> **Дата:** июнь 2025

---

## Содержание

1. [Чек‑лист перед началом](#чек‑лист-перед-началом)
2. [Задание 1: Инициализация и создание сети](#задание-1-инициализация-и-создание-сети)
3. [Задание 2: Создание VM с count и for\_each](#задание-2-создание-vm-с-count-и-for_each)
4. [Задание 3: Диски и VM «storage»](#задание-3-диски-и-vm-storage)
5. [Задание 4: Динамический Ansible‑инвентарь](#задание-4-динамический-ansible-инвентарь)
6. [Задание 5: Output всех VM](#задание-5-output-всех-vm)
7. [Задание 6\*: Ansible-плейбук через null\_resource](#задание-6-ansible-плейбук-через-null_resource)
8. [Задание 7: Удаление 3-го элемента в консоли](#задание-7-удаление-3-го-элемента-в-консоли)
9. [Задание 8: Исправление ошибки в tpl](#задание-8-исправление-ошибки-в-tpl)
10. [Задание 9\*: Генерация списков в консоли](#задание-9-генерация-списков-в-консоли)

---

## Чек‑лист перед началом

- Установлена **Terraform 1.8.4**
- Установлен **YC CLI 0.150.0** и выполнён `yc init`
- Сгенерирован OAuth‑токен (`yc iam create-token`) и сохранён в `terraform.tfvars`
- Публичный SSH‑ключ доступен в `~/.ssh/id_rsa.pub`

---

## Задание 1: Инициализация и создание сети

**Команды:**

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

**Проверка:**

| Ресурс                                | Пример вывода                       |
| ------------------------------------- | ----------------------------------- |
| Сеть `yandex_vpc_network.develop`     | `yandex_vpc_network.develop`        |
| Подсеть `yandex_vpc_subnet.develop`   | `yandex_vpc_subnet.develop`         |
| Группа безопасности `example_dynamic` | `yandex_vpc_security_group.example` |


---

## Задание 2: Создание VM с count и for\_each

### 2.1 `count-vm.tf`

```hcl
resource "yandex_compute_instance" "web" {
  count                      = 2
  name                       = format("web-%d", count.index + 1)
  folder_id                  = var.folder_id
  zone                       = var.default_zone
  platform_id                = "standard-v1"
  resources { cores = 1; memory = 2 }
  boot_disk { initialize_params { image_id = data.yandex_compute_image.ubuntu.id; size = 5; type = "network-hdd" } }
  network_interface { subnet_id = yandex_vpc_subnet.develop.id; nat = true; security_group_ids = [yandex_vpc_security_group.example.id] }
  scheduling_policy { preemptible = true }
  allow_stopping_for_update = true
  metadata = { ssh-keys = file("~/.ssh/id_rsa.pub") }
  depends_on = [yandex_compute_instance.db]
}
```

| Проверка        | Результат                           |
| --------------- | ----------------------------------- |
| Terraform State | `yandex_compute_instance.web[0..1]` | 

### 2.2 `for_each-vm.tf`

```hcl
variable "each_vm" {
  type    = list(object({ vm_name=string, cpu=number, ram=number, disk_volume=number }))
  default = [
    { vm_name = "main",    cpu=2, ram=4, disk_volume=20 },
    { vm_name = "replica", cpu=1, ram=2, disk_volume=10 },
  ]
}

data "yandex_compute_image" "ubuntu" { family = "ubuntu-2204-lts" }

resource "yandex_compute_instance" "db" {
  for_each = { for vm in var.each_vm : vm.vm_name => vm }
  name     = each.value.vm_name
  folder_id= var.folder_id
  zone     = var.default_zone
  platform_id = "standard-v1"
  resources { cores = each.value.cpu; memory = each.value.ram }
  boot_disk { initialize_params { image_id = data.yandex_compute_image.ubuntu.id; size = each.value.disk_volume; type = "network-hdd" } }
  network_interface { subnet_id = yandex_vpc_subnet.develop.id; nat = true; security_group_ids = [yandex_vpc_security_group.example.id] }
  allow_stopping_for_update = true
  metadata = { ssh-keys = file("~/.ssh/id_rsa.pub") }
}
```

| Проверка        | Результат                                             |
| --------------- | ----------------------------------------------------- |
| Terraform State | `yandex_compute_instance.db["main"]`, `db["replica"]` | 

![Terraform State](https://github.com/asad-bekov/hw-24/raw/main/img/2.png)

---

## Задание 3: Диски и VM «storage»

```hcl
resource "yandex_compute_disk" "additional" {
  count = 3
  name  = format("storage-disk-%d", count.index + 1)
  zone  = var.default_zone
  type  = "network-hdd"
  size  = 1
}

resource "yandex_compute_instance" "storage" {
  name        = "storage"
  folder_id   = var.folder_id
  zone        = var.default_zone
  platform_id = "standard-v1"
  resources { cores=1; memory=2 }
  boot_disk { initialize_params { image_id = data.yandex_compute_image.ubuntu.id; size=10; type="network-hdd" } }
  network_interface { subnet_id = yandex_vpc_subnet.develop.id; nat=false; security_group_ids=[yandex_vpc_security_group.example.id] }
  dynamic "secondary_disk" {
    for_each = yandex_compute_disk.additional
    content { disk_id = secondary_disk.value.id; device_name = secondary_disk.value.name }
  }
  allow_stopping_for_update = true
  metadata = { ssh-keys = file("~/.ssh/id_rsa.pub") }
}
```

| Проверка           | Результат                     | Скриншот |
| ------------------ | ----------------------------- | -------- |
| Диски + VM Storage | `additional[0..2]`, `storage` |          |

![Terraform State](https://github.com/asad-bekov/hw-24/raw/main/img/3.png)
---

## Задание 4: Динамический Ansible‑инвентарь

### Шаблон `templates/inventory.tpl`

```tpl
[webservers]
%{ for vm in webservers }
${vm.name} ansible_host=${vm.ansible_host} fqdn=${vm.fqdn}
%{ endfor }

[databases]
%{ for vm in databases }
${vm.name} ansible_host=${vm.ansible_host} fqdn=${vm.fqdn}
%{ endfor }

[storage]
%{ for vm in storage }
${vm.name} ansible_host=${vm.ansible_host} fqdn=${vm.fqdn}
%{ endfor }
```

### Конфиг `ansible.tf`

```hcl
provider "local" {}

locals {
  webservers = [ for inst in yandex_compute_instance.web : { name=inst.name; fqdn=inst.fqdn; ansible_host=inst.network_interface[0].nat_ip_address != "" ? inst.network_interface[0].nat_ip_address : inst.network_interface[0].ip_address } ]
  databases  = [ for inst in values(yandex_compute_instance.db) : { name=inst.name; fqdn=inst.fqdn; ansible_host=inst.network_interface[0].nat_ip_address != "" ? inst.network_interface[0].nat_ip_address : inst.network_interface[0].ip_address } ]
  storage    = [ { name=yandex_compute_instance.storage.name; fqdn=yandex_compute_instance.storage.fqdn; ansible_host=yandex_compute_instance.storage.network_interface[0].nat_ip_address != "" ? yandex_compute_instance.storage.network_interface[0].nat_ip_address : yandex_compute_instance.storage.network_interface[0].ip_address } ]
}

resource "local_file" "ansible_inventory" {
  content  = templatefile("${path.module}/templates/inventory.tpl", { webservers=local.webservers, databases=local.databases, storage=local.storage })
  filename = "${path.module}/inventory.ini"
}
```

| Проверка                | Результат   |
| ----------------------- | ----------- |
| Генерация inventory.ini | файл создан |

![Terraform State](https://github.com/asad-bekov/hw-24/raw/main/img/4.png)
---

## Задание 5: Output всех VM

```hcl
output "all_vms" {
  value = concat(
    [ for inst in yandex_compute_instance.web  : { name=inst.name; id=inst.id; fqdn=inst.fqdn } ],
    [ for inst in values(yandex_compute_instance.db) : { name=inst.name; id=inst.id; fqdn=inst.fqdn } ]
  )
}
```

| Проверка                   | Вывод                | 
| -------------------------- | -------------------- | 
| `terraform output all_vms` | список словарей JSON | 

![Terraform State](https://github.com/asad-bekov/hw-24/raw/main/img/5.png
---

## Задание 6\*: Ansible-плейбук через `null_resource`

### Playbook `playbook.yml`

```yaml
---
- name: Test connectivity to all hosts
  hosts: all
  gather_facts: no
  tasks:
    - name: Ping hosts
      ansible.builtin.ping:
```

```hcl
resource "null_resource" "run_playbook" {
  depends_on = [ local_file.ansible_inventory ]
  triggers   = { inv_sha = filesha256(local_file.ansible_inventory.filename) }
  provisioner "local-exec" {
    command     = "ansible-playbook -i inventory.ini playbook.yml"
    working_dir = path.module
  }
}
```

| Проверка        | Результат                         |
| --------------- | --------------------------------- | 
| Запуск плейбука | все хосты UNREACHABLE (nat=false) |

![Terraform State](https://github.com/asad-bekov/hw-24/raw/main/img/6.png)
---

## Задание 7: Удаление 3-го элемента в консоли

```bash
> { network_id=local.vpc.network_id, subnet_ids=[for i,id in local.vpc.subnet_ids : id if i!=2], subnet_zones=[for i,z in local.vpc.subnet_zones : z if i!=2] }
```

| Проверка          | Результат                    | 
| ----------------- | ---------------------------- | 
| Terraform Console | объект без третьего элемента |

![Terraform State](https://github.com/asad-bekov/hw-24/raw/main/img/7.png)

---

## Задание 8: Исправление ошибки в tpl

```bash
terraform plan
```

| Ошибка                                                           | Исправление                                 |
| ---------------------------------------------------------------- | --------------------------------------------------------------------------- |
|-[webservers]
-%{~ for i in webservers ~}
-${i["name"]} ansible_host=${i["network_interface"][0]["nat_ip_address"] platform_id=${i["platform_id "]}}
-%{~ endfor ~} | 
|+[webservers]
+%{ for i in webservers }
+${i.name} ansible_host=${i.network_interface[0].nat_ip_address} platform_id=${i.platform_id}
+%{ endfor %}| 


**Примечание**:

1. Закрыли `}` после `${i.network_interface[0].nat_ip_address}`.
2. Убрали пробел в ключе `"platform_id "` → `"platform_id"`.
3. Перешли на точечную нотацию (`i.name`, `i.platform_id`) для читаемости.
4. Упростили управляющие теги до `%{ for … }` / `%{ endfor }` (тильды не обязательны).

| Проверка         | Результат после исправления |
| ---------------- | --------------------------- |
| `terraform plan` | без ошибок                  |
|  | планится только пересоздать `null_resource.run_playbook`|

![terraform plan](https://github.com/asad-bekov/hw-24/raw/main/img/8.png)
---

## Задание 9\*: Генерация списков в консоли

| Описание                          | Выражение                                                          |
| --------------------------------- | ------------------------------------------------------------------ |
| `rc01`…`rc99`                     | `> jsonencode([for n in range(1,100) : format("rc%02d", n)])`       |
| `rc01`…`rc96`, без 0,7,8,9 + rc19 | `> jsonencode([for n in range(1, 97) : format("rc%02d", n) if n == 19 || !contains([0,7,8,9], n % 10)])` |

![Выводы](https://github.com/asad-bekov/hw-24/raw/main/img/9.png)
---

**Ссылка на ветку с решением:** [terraform-03](https://github.com/asad-bekov/hw-24/tree/terraform-03)

---

*Все задания выполнены без хардкода, с использованием переменных, локалов, динамических блоков. 


