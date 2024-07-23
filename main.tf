terraform {
  required_providers {
    selectel = {
      source  = "selectel/selectel"
      version = "5.1.1"
    }
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "2.0.0"
    }
  }
}

variable "selectel_password" {}
variable "selectel_radozhickij_uuid" {}
variable "service_user_uid" {}

provider "selectel" {
  domain_name = "61244"
  username    = "Radozhitskiy"
  password    = var.selectel_password
}

provider "openstack" {
  auth_url    = "https://cloud.api.selcloud.ru/identity/v3"
  domain_name = "61244"
  tenant_id   = var.selectel_radozhickij_uuid
  user_name   = "Radozhitskiy"
  password    = var.selectel_password
  region      = "ru-9"
}

resource "selectel_vpc_keypair_v2" "keypair_1" {
  name       = "keypair"
  public_key = file("~/.ssh/the-key.pub")
  user_id    = var.service_user_uid
}

#resource "openstack_compute_flavor_v2" "flavor_1" {
#  name      = "custom-flavor-with-network-volume"
#  vcpus     = 2
#  ram       = 4096
#  disk      = 0
#  flavor_id = "SL1.2-4096"
#  is_public = false
#
#  lifecycle {
#    create_before_destroy = true
#  }
#}

variable "radozhickij_network_id" {
  default = ""
}

variable "radozhickij_subnet_id" {
  default = ""
}

resource "openstack_networking_port_v2" "port_1" {
  name       = "port"
  network_id = var.radozhickij_network_id

  fixed_ip {
    subnet_id = var.radozhickij_subnet_id
  }
}
resource "openstack_networking_port_v2" "port_2" {
  name       = "port-2"
  network_id = var.radozhickij_network_id

  fixed_ip {
    subnet_id = var.radozhickij_subnet_id
  }
}

data "openstack_images_image_v2" "image_1" {
  name        = "Ubuntu 20.04 LTS 64-bit"
  most_recent = true
  visibility  = "public"
}

resource "openstack_blockstorage_volume_v3" "volume_1" {
  name                 = "boot-volume-for-server"
  size                 = "5"
  image_id             = data.openstack_images_image_v2.image_1.id
  volume_type          = "fast.ru-9a"
  availability_zone    = "ru-9a"
  enable_online_resize = true

  lifecycle {
    ignore_changes = [image_id]
  }

}

resource "openstack_blockstorage_volume_v3" "volume_2" {
  name                 = "additional-volume-for-server"
  size                 = "7"
  volume_type          = "universal.ru-9a"
  availability_zone    = "ru-9a"
  enable_online_resize = true
}

resource "openstack_blockstorage_volume_v3" "volume_1_1" {
  name                 = "boot-volume-for-server"
  size                 = "5"
  image_id             = data.openstack_images_image_v2.image_1.id
  volume_type          = "fast.ru-9a"
  availability_zone    = "ru-9a"
  enable_online_resize = true

  lifecycle {
    ignore_changes = [image_id]
  }

}

resource "openstack_blockstorage_volume_v3" "volume_2_1" {
  name                 = "additional-volume-for-server"
  size                 = "7"
  volume_type          = "universal.ru-9a"
  availability_zone    = "ru-9a"
  enable_online_resize = true
}

resource "openstack_compute_instance_v2" "server_1" {
  name              = "server"
  flavor_id         = "1013" #"SL1.2-4096" #openstack_compute_flavor_v2.flavor_1.id
  key_pair          = selectel_vpc_keypair_v2.keypair_1.name
  availability_zone = "ru-9a"

  network {
    port = openstack_networking_port_v2.port_1.id
  }

  lifecycle {
    ignore_changes = [image_id]
  }

  block_device {
    uuid             = openstack_blockstorage_volume_v3.volume_1.id
    source_type      = "volume"
    destination_type = "volume"
    boot_index       = 0
  }

  block_device {
    uuid             = openstack_blockstorage_volume_v3.volume_2.id
    source_type      = "volume"
    destination_type = "volume"
    boot_index       = -1
  }

  vendor_options {
    ignore_resize_confirmation = true
  }
}

resource "openstack_compute_instance_v2" "server_2" {
  name              = "serve2"
  flavor_id         = "1013" #"SL1.2-4096" #openstack_compute_flavor_v2.flavor_1.id
  key_pair          = selectel_vpc_keypair_v2.keypair_1.name
  availability_zone = "ru-9a"

  network {
    port = openstack_networking_port_v2.port_2.id
  }

  lifecycle {
    ignore_changes = [image_id]
  }

  block_device {
    uuid             = openstack_blockstorage_volume_v3.volume_1_1.id
    source_type      = "volume"
    destination_type = "volume"
    boot_index       = 0
  }

  block_device {
    uuid             = openstack_blockstorage_volume_v3.volume_2_1.id
    source_type      = "volume"
    destination_type = "volume"
    boot_index       = -1
  }

  vendor_options {
    ignore_resize_confirmation = true
  }
}

resource "openstack_networking_floatingip_v2" "floatingip_1" {
  pool = "external-network"
}

resource "openstack_networking_floatingip_v2" "floatingip_2" {
  pool = "external-network"
}

resource "openstack_networking_floatingip_associate_v2" "association_1" {
  port_id     = openstack_networking_port_v2.port_1.id
  floating_ip = openstack_networking_floatingip_v2.floatingip_1.address
}

resource "openstack_networking_floatingip_associate_v2" "association_2" {
  port_id     = openstack_networking_port_v2.port_2.id
  floating_ip = openstack_networking_floatingip_v2.floatingip_2.address
}

output "private_ip_address" {
  value = openstack_networking_floatingip_v2.floatingip_1.fixed_ip  #address
}
output "public_ip_address" {
  value = openstack_networking_floatingip_v2.floatingip_1.address
}

output "private_ip_address_2" {
  value = openstack_networking_floatingip_v2.floatingip_2.fixed_ip  #address
  depends_on = [openstack_networking_floatingip_v2.floatingip_2]
}
output "public_ip_address_2" {
  value = openstack_networking_floatingip_v2.floatingip_2.address
  depends_on = [openstack_networking_floatingip_v2.floatingip_2]
}

resource "openstack_lb_loadbalancer_v2" "load_balancer_1" {
  name          = "load-balancer"
  vip_subnet_id = var.radozhickij_subnet_id
  flavor_id     = "3265f75f-01eb-456d-9088-44b813d29a60"
}

resource "openstack_lb_listener_v2" "listener_1" {
  name            = "listener"
  protocol        = "TCP"
  protocol_port   = "80"
  loadbalancer_id = openstack_lb_loadbalancer_v2.load_balancer_1.id
}

resource "openstack_lb_pool_v2" "pool_1" {
  name        = "pool"
  protocol    = "PROXY"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.listener_1.id
}

resource "openstack_lb_member_v2" "member_1" {
  name          = "member_1"
  subnet_id     = var.radozhickij_subnet_id
  pool_id       = openstack_lb_pool_v2.pool_1.id
  address       = openstack_networking_floatingip_v2.floatingip_1.fixed_ip
  protocol_port = "80"
}

resource "openstack_lb_member_v2" "member_2" {
  name          = "member_2"
  subnet_id     = var.radozhickij_subnet_id
  pool_id       = openstack_lb_pool_v2.pool_1.id
  address       = openstack_networking_floatingip_v2.floatingip_2.fixed_ip
  protocol_port = "80"
  depends_on = [openstack_networking_floatingip_v2.floatingip_2]
}

resource "openstack_lb_monitor_v2" "monitor_1" {
  name        = "monitor"
  pool_id     = openstack_lb_pool_v2.pool_1.id
  type        = "HTTP"
  delay       = "10"
  timeout     = "4"
  max_retries = "5"
}

resource "openstack_networking_floatingip_v2" "floatingip_3" {
  pool    = "external-network"
  port_id = openstack_lb_loadbalancer_v2.load_balancer_1.vip_port_id
}

output "public_ip_address_lb" {
  value = openstack_networking_floatingip_v2.floatingip_3.address
}

data "selectel_dbaas_datastore_type_v1" "datastore_type_1" {
  project_id = var.selectel_radozhickij_uuid
  region     = "ru-9"
  filter {
    engine  = "postgresql"
    version = "16"
  }
}

output "dbaas" {
  value = data.selectel_dbaas_datastore_type_v1.datastore_type_1
}