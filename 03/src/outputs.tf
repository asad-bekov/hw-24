output "all_vms" {
  description = "Список всех VM (web + db + storage) в виде словарей"
  value = concat(
    [
      for inst in yandex_compute_instance.web : {
        name = inst.name
        id   = inst.id
        fqdn = inst.fqdn
      }
    ],
    [
      for inst in values(yandex_compute_instance.db) : {
        name = inst.name
        id   = inst.id
        fqdn = inst.fqdn
      }
    ],
    [
      for inst in [yandex_compute_instance.storage] : {
        name = inst.name
        id   = inst.id
        fqdn = inst.fqdn
      }
    ]
  )
}