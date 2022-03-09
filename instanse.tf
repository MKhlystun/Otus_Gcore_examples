# Описываем уже имеющиеся ресурсы в облаке
data "gcore_project" "pr" {
  name = "Otus"
}

data "gcore_region" "rg" {
  name = "Saint Petersburg"
}

data "gcore_image" "ubuntu" {
  name = "ubuntu-20.04"
  region_id = data.gcore_region.rg.id
  project_id = data.gcore_project.pr.id
}

data "gcore_securitygroup" "default" {
  name = "default"
  region_id = data.gcore_region.rg.id
  project_id = data.gcore_project.pr.id
}

#Создаем новые ресурсы
#Сеть
resource "gcore_network" "network" {
  name = "network_example"
  mtu = 1450
  type = "vxlan"
  region_id = data.gcore_region.rg.id
  project_id = data.gcore_project.pr.id
}

#Подсеть
resource "gcore_subnet" "subnet" {
  name = "subnet_example"
  cidr = "192.168.10.0/24"
  network_id = gcore_network.network.id
  dns_nameservers = ["8.8.4.4", "1.1.1.1"]

  host_routes {
    destination = "10.0.3.0/24"
    nexthop = "10.0.0.13"
  }

  gateway_ip = "192.168.10.1"
  region_id = data.gcore_region.rg.id
  project_id = data.gcore_project.pr.id
}
#Фиксированный адрес
resource "gcore_reservedfixedip" "fixed_ip" {
  project_id = data.gcore_project.pr.id
  region_id = data.gcore_region.rg.id
  type = "ip_address"
  network_id = gcore_network.network.id
  fixed_ip_address = "192.168.10.6"
  is_vip = false
}

resource "gcore_floatingip" "fip" {
  project_id = data.gcore_project.pr.id
  region_id = data.gcore_region.rg.id
  fixed_ip_address = gcore_reservedfixedip.fixed_ip.fixed_ip_address
  port_id = gcore_reservedfixedip.fixed_ip.port_id
}

resource "gcore_volume" "first_volume" {
  name = "boot volume"
  type_name = "ssd_hiiops"
  size = 5
  image_id = data.gcore_image.ubuntu.id
  region_id = data.gcore_region.rg.id
  project_id = data.gcore_project.pr.id
}

resource "gcore_volume" "second_volume" {
  name = "second volume"
  type_name = "ssd_hiiops"
  size = 35
  region_id = data.gcore_region.rg.id
  project_id = data.gcore_project.pr.id
}

resource "gcore_instance" "instance" {
  flavor_id = "g0-standard-2-4"
  name = "vm1"
  keypair_name = "mkhlystun"

  volume {
    source = "existing-volume"
    volume_id = gcore_volume.first_volume.id
    boot_index = 0
  }

  volume {
    source = "existing-volume"
    volume_id = gcore_volume.second_volume.id
    boot_index = 1
  }

  interface {
    type = "reserved_fixed_ip"
        port_id = gcore_reservedfixedip.fixed_ip.port_id
        fip_source = "existing"
        existing_fip_id = gcore_floatingip.fip.id
  }

  security_group {
    id = data.gcore_securitygroup.default.id
    name = "default"
  }

  metadata_map = {
    some_key = "some_value"
    stage = "dev"
  }

  configuration {
    key = "some_key"
    value = "some_data"
  }

  region_id = data.gcore_region.rg.id
  project_id = data.gcore_project.pr.id
}
