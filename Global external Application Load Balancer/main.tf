provider "google" {
 project = ""
 region = "europe-west2"
}

resource "google_compute_network" "vpc" {
 name                  = "vpc-1"
 auto_create_subnetworks = false
 mtu                   = 1460
}

resource "google_compute_subnetwork" "subnet" {
 name         = "subnet-1"
 ip_cidr_range = "10.0.0.0/24"
 network      = google_compute_network.vpc.self_link
 region       = "europe-west2"

 private_ip_google_access = true

 log_config {
   aggregation_interval = "INTERVAL_5_SEC"
   flow_sampling       = 1
   metadata            = "INCLUDE_ALL_METADATA"
 }
}

## Firewall rule

resource "google_compute_firewall" "intra" {
 name   = "intra"
 network = google_compute_network.vpc.self_link

 allow {
   protocol = "all"
 }

 source_ranges = ["10.0.0.0/24"]
 destination_ranges = ["10.0.0.0/24"]

 direction  = "INGRESS"
 priority   = 1000
 description = "Allow intra-VPC traffic"

 log_config {
   metadata = "INCLUDE_ALL_METADATA"
 }
}

## Firewall rule

resource "google_compute_firewall" "iap" {
 name   = "iap"
 network = google_compute_network.vpc.self_link

 allow {
   protocol = "TCP"
   ports = ["22"]
 }

 source_ranges = ["35.235.240.0/20"]
 destination_ranges = ["10.0.0.0/24"]

 direction  = "INGRESS"
 priority   = 1000
 description = "Allow IAP for browser SSH"

 log_config {
   metadata = "INCLUDE_ALL_METADATA"
 }
}


## Firewall rule

resource "google_compute_firewall" "healthcheck" {
 name   = "healthcheck"
 network = google_compute_network.vpc.self_link

 allow {
   protocol = "TCP"
   ports = ["80"]
 }

 source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
 target_tags = ["nginx"]

 direction  = "INGRESS"
 priority   = 1000
 description = "Allow healthcheck"

 log_config {
   metadata = "INCLUDE_ALL_METADATA"
 }
}

resource "google_compute_router" "router" {
 name   = "router-1"
 region = "europe-west2"
 network = google_compute_network.vpc.self_link

 bgp {
  asn = 64513
  advertise_mode    = "CUSTOM"

  advertised_ip_ranges {
    range = "10.0.0.0/24"
  }

  advertised_ip_ranges {
    range = "10.100.0.0/24"
  }
 }
}

resource "google_compute_router_nat" "nat-vpc1" {
 router = google_compute_router.router.name 
 region = "europe-west2"

 name = "nat-vpc1"
 enable_dynamic_port_allocation      = true
 nat_ip_allocate_option           = "AUTO_ONLY"
 min_ports_per_vm                = 64

source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = "subnet-1"
    source_ip_ranges_to_nat = ["10.0.0.0/24"]
  }

 log_config {
 enable = true
 filter = "ALL"
 }
}

resource "google_compute_instance" "vm_instance" {
 name        = "mgmt-vpc1"
 machine_type = "e2-medium"
 zone        = "europe-west2-a"

 tags = ["mgmtvpc1"]

 boot_disk {
  initialize_params {
    image = "debian-cloud/debian-11"
    size = 10
  }
 }

 network_interface {
  network = google_compute_network.vpc.self_link
  subnetwork = google_compute_subnetwork.subnet.self_link
  network_ip = "10.0.0.10"
 }

 scheduling {
  preemptible = false
  automatic_restart = true
 }

 labels = {
  mgmt = "vpc-1"
 }

 can_ip_forward = true

 metadata_startup_script = "apt install apache2 -y; apt install tcpdump -y"

 service_account {
  email = "default"
  scopes = ["cloud-platform"]
 }

 hostname = "mgmt-vpc1.internal"
}


#vm_instance

resource "google_compute_instance" "vm_instance2" {
 name        = "nginx-backend-neg-vpc1"
 machine_type = "e2-medium"
 zone        = "europe-west2-a"

 tags = ["nginx"]

 boot_disk {
  initialize_params {
    image = "debian-cloud/debian-11"
    size = 10
  }
 }

 network_interface {
  network = google_compute_network.vpc.self_link
  subnetwork = google_compute_subnetwork.subnet.self_link
  network_ip = "10.0.0.11"
 }

 scheduling {
  preemptible = false
  automatic_restart = true
 }

 labels = {
  backend = "nginx"
 }

 can_ip_forward = true

 metadata_startup_script = "apt install apache2 -y; apt install tcpdump -y; echo 'tusmuertos' > /var/www/html/index.html"

 service_account {
  email = "default"
  scopes = ["cloud-platform"]
 }

 hostname = "backend-nginx-neg-vpc1.internal"
}


resource "google_compute_network_endpoint_group" "neg" {
  name         = "nginx-neg"
  network      = google_compute_network.vpc.self_link
  subnetwork   = google_compute_subnetwork.subnet.self_link
  default_port = "80"
  zone         = "europe-west2-a"
}

resource "google_compute_network_endpoint" "default-endpoint" {
  network_endpoint_group = google_compute_network_endpoint_group.neg.self_link
  instance = google_compute_instance.vm_instance2.self_link 
  zone         = "europe-west2-a"
  port = "80"
  ip_address = "10.0.0.11"
}

resource "google_compute_health_check" "http-health-check" {
  name        = "nginx-hc"
  description = "Health check via http"

  timeout_sec         = 1
  check_interval_sec  = 1
  healthy_threshold   = 2
  unhealthy_threshold = 5

  http_health_check {
    port               = "80"
    host               = google_compute_instance.vm_instance2.network_interface[0].network_ip
    request_path       = "/"
  }

log_config {
    enable = true
    }
}

resource "google_compute_backend_service" "backend-1" {
  name                  = "backend-1"
  protocol              = "HTTP"
  timeout_sec           = 10
  load_balancing_scheme = "EXTERNAL_MANAGED"
  session_affinity      = "HTTP_COOKIE"

  custom_request_headers          = ["host: jaja"]
  custom_response_headers         = ["tusmuertos: hijoputa"]

  backend {
    group = google_compute_network_endpoint_group.neg.id
    balancing_mode = "RATE"
    max_rate_per_endpoint = "1000"
  }

  health_checks = [google_compute_health_check.http-health-check.self_link]

  log_config {
   enable            = true
   sample_rate       = 1
   
 }
}

resource "google_compute_url_map" "urlmap" {
  name        = "urlmap"
  description = "Test urklmap"

  default_service = google_compute_backend_service.backend-1.self_link

  host_rule {
    hosts        = ["mysite.com"]
    path_matcher = "mysite"
  }

  path_matcher {
    name            = "mysite"
    default_service = google_compute_backend_service.backend-1.self_link

    path_rule {
      paths   = ["/home"]
      service = google_compute_backend_service.backend-1.self_link
    }
  }
}

resource "google_compute_target_http_proxy" "http-proxy" {
  name    = "http-proxy"
  url_map = google_compute_url_map.urlmap.self_link
}

resource "google_compute_global_forwarding_rule" "frontend-http" {
  name                  = "frontend-http"
  target                = google_compute_target_http_proxy.http-proxy.self_link
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
