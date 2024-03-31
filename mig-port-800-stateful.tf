resource "google_service_account" "backend-sa" {
  account_id   = "backend-sa"
  display_name = "Service Account for backend VMs"
}

resource "google_compute_instance_template" "backend-vm-template-800" {
  name = "backend-vm-template-800"

  instance_description    = "backend vm"
  machine_type            = "e2-medium"
  region                  = var.network.region
  metadata_startup_script = "sudo socat TCP-LISTEN:800,fork FD:1&"

  resource_manager_tags = {
    (google_tags_tag_value.content-backend.parent) = google_tags_tag_value.content-backend.id
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  disk {
    source_image = var.source-image
    auto_delete  = true
    boot         = true
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.subnetwork.id
  }

  service_account {
    email  = google_service_account.backend-sa.email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_health_check" "backend-autoheal-health-check-800" {
  name                = "backend-autoheal-health-check-800"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 10 # 50 seconds

  tcp_health_check {
    port = "800"
  }
}

#
resource "google_compute_region_instance_group_manager" "backend-mig-800" {
  name = "backend-mig-800"

  base_instance_name        = "backend-800"
  region                    = var.network.region
  distribution_policy_zones = var.ilb-zones

  version {
    instance_template = google_compute_instance_template.backend-vm-template-800.self_link
  }

  #target_size = 0
  update_policy {
    type                         = "OPPORTUNISTIC"
    instance_redistribution_type = "NONE"
    minimal_action               = "REFRESH"
    max_unavailable_fixed        = 2
  }


}

resource "google_compute_address" "instance-1-address" {
  name         = "instance-1-address"
  address_type = "EXTERNAL"
  region       = var.network.region
}

resource "google_compute_address" "instance-2-address" {
  name         = "instance-2-address"
  address_type = "EXTERNAL"
  region       = var.network.region
}

resource "google_compute_region_per_instance_config" "instance-1" {
  region = google_compute_region_instance_group_manager.backend-mig-800.region
  region_instance_group_manager = google_compute_region_instance_group_manager.backend-mig-800.name
  name                          = "instance-1"
  preserved_state {
    metadata = {
      // Adding a reference to the instance template used causes the stateful instance to update
      // if the instance template changes. Otherwise there is no explicit dependency and template
      // changes may not occur on the stateful instance
      instance_template = google_compute_instance_template.backend-vm-template-800.self_link_unique
    }

    # disk {
    #   device_name = "my-stateful-disk"
    #   source      = google_compute_disk.default.id
    #   mode        = "READ_ONLY"
    # }

    external_ip {
      interface_name = "nic0"
      auto_delete    = "NEVER"
      ip_address {
        address = google_compute_address.instance-1-address.self_link
      }
    }
  }
}

resource "google_compute_region_per_instance_config" "instance-2" {
  region = google_compute_region_instance_group_manager.backend-mig-800.region
  region_instance_group_manager = google_compute_region_instance_group_manager.backend-mig-800.name
  name                          = "instance-2"
  preserved_state {
    metadata = {
      // Adding a reference to the instance template used causes the stateful instance to update
      // if the instance template changes. Otherwise there is no explicit dependency and template
      // changes may not occur on the stateful instance
      instance_template = google_compute_instance_template.backend-vm-template-800.self_link_unique
    }

    # disk {
    #   device_name = "my-stateful-disk"
    #   source      = google_compute_disk.default.id
    #   mode        = "READ_ONLY"
    # }

    external_ip {
      interface_name = "nic0"
      auto_delete    = "NEVER"
      ip_address {
        address = google_compute_address.instance-2-address.self_link
      }
    }
  }
}