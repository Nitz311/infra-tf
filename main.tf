provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone

}

terraform {
  backend "gcs" {
    bucket = "thudarum2015"
    prefix = "terraform/state"
    
  }
}

resource "google_compute_instance_template" "web_template" {
  name         = "web-template"
  machine_type = "e2-micro"

  disk {
    source_image = "debian-cloud/debian-10"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network = "default"
    access_config {
      // Ephemeral IP
    }
  }

  metadata_startup_script = <<-EOT
              #!/bin/bash
              apt-get update
              apt-get install -y nginx
              systemctl start nginx
                systemctl enable nginx
                 echo "Hello from $(hostname)" > /var/www/html/index.html
            EOT



  tags = ["http-server"]

}

resource "google_compute_health_check" "http" {
  name                = "http-health-check"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    port         = "80"
    request_path = "/"
  }

}

resource "google_compute_instance_group_manager" "web_mig" {
  name               = "web-mig"
  base_instance_name = "web-instance"
  zone               = var.zone
  version {
    instance_template = google_compute_instance_template.web_template.id
  }
  target_size = 2
  named_port {
    name = "http"
    port = 80
  }
}

resource "google_compute_backend_service" "default" {
  name          = "web-backend-service"
  protocol      = "HTTP"
  port_name     = "http"
  timeout_sec   = 10
  health_checks = [google_compute_health_check.http.id]
  backend {
    group = google_compute_instance_group_manager.web_mig.instance_group
  }
}

resource "google_compute_url_map" "default" {
  name            = "web-url-map"
  default_service = google_compute_backend_service.default.id
}

resource "google_compute_target_http_proxy" "default" {
  name    = "web-http-proxy"
  url_map = google_compute_url_map.default.id
}

resource "google_compute_global_address" "default" {
  name = "web-static-ip"
}

resource "google_compute_global_forwarding_rule" "default" {
  name       = "web-http-rule"
  ip_address = google_compute_global_address.default.address
  port_range = "80"
  target     = google_compute_target_http_proxy.default.id
}

