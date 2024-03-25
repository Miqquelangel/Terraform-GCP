provider "google" {
 region = "europe-west2"
}

#Create Hub VPC

resource "google_compute_network" "hub-vpc" {
 name                  = "hub-vpc"
 auto_create_subnetworks = false
 mtu                   = 1460
}

#Create Spoke VPC

resource "google_compute_network" "spoke-vpc" {
 name                  = "spoke-vpc"
 auto_create_subnetworks = false
 mtu                   = 1460
}

#Create Hub subnet

resource "google_compute_subnetwork" "hub-subnet-1" {
 name         = "hub-subnet-1"
 ip_cidr_range = "10.200.0.0/24"
 network      = google_compute_network.hub-vpc.self_link
 region       = "europe-west2"

 private_ip_google_access = true

 log_config {
   aggregation_interval = "INTERVAL_5_SEC"
   flow_sampling       = 1
   metadata            = "INCLUDE_ALL_METADATA"
 }
}

#Create Spoke subnets

resource "google_compute_subnetwork" "spoke-subnet-1" {
 name         = "spoke-subnet-1"
 ip_cidr_range = "10.0.0.0/24"
 network      = google_compute_network.spoke-vpc.self_link
 region       = "europe-west2"

 private_ip_google_access = true

 log_config {
   aggregation_interval = "INTERVAL_5_SEC"
   flow_sampling       = 1
   metadata            = "INCLUDE_ALL_METADATA"
 }
}

resource "google_compute_subnetwork" "spoke-subnet-2" {
 name         = "spoke-subnet-2"
 ip_cidr_range = "10.10.0.0/24"
 network      = google_compute_network.spoke-vpc.self_link
 region       = "europe-west2"

 private_ip_google_access = true

 log_config {
   aggregation_interval = "INTERVAL_5_SEC"
   flow_sampling       = 1
   metadata            = "INCLUDE_ALL_METADATA"
 }
}

# Create a VPC peering between Hub and Spoke VPCs

resource "google_compute_network_peering" "hub-spoke" {
  name         = "hub-spoke"
  network      = google_compute_network.hub-vpc.self_link
  peer_network = google_compute_network.spoke-vpc.self_link
}

resource "google_compute_network_peering" "spoke-hub" {
  name         = "spoke-hub"
  network      = google_compute_network.spoke-vpc.self_link
  peer_network = google_compute_network.hub-vpc.self_link
}

# Create Firewall rules for the Hub VPC

resource "google_compute_firewall" "hub-intra-fw" {
 name   = "intra-hub-subnet-1"
 network = google_compute_network.hub-vpc.self_link

 allow {
   protocol = "all"
 }

 source_ranges = ["10.200.0.0/24"]
 destination_ranges = ["10.200.0.0/24"]

 direction  = "INGRESS"
 priority   = 1000
 description = "Allow intra-VPC traffic"

 log_config {
   metadata = "INCLUDE_ALL_METADATA"
 }
}

########################################################

resource "google_compute_firewall" "hub-iap-fw" {
 name   = "iap-hub-subnet-1"
 network = google_compute_network.hub-vpc.self_link

 allow {
   protocol = "TCP"
   ports = ["22"]
 }

 source_ranges = ["35.235.240.0/20"]
 destination_ranges = ["10.200.0.0/24"]

 direction  = "INGRESS"
 priority   = 1000
 description = "Allow IAP for browser SSH"

 log_config {
   metadata = "INCLUDE_ALL_METADATA"
 }
}

########################################################

resource "google_compute_firewall" "hub-healthcheck-fw" {
 name   = "healthcheck-hub-subnet-1"
 network = google_compute_network.hub-vpc.self_link

 allow {
   protocol = "TCP"
   ports = ["80"]
 }

 source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
 destination_ranges = ["10.200.0.0/24"]

 direction  = "INGRESS"
 priority   = 1000
 description = "Allow healthcheck"

 log_config {
   metadata = "INCLUDE_ALL_METADATA"
 }
}

########################################################

resource "google_compute_firewall" "hub-peering-fw" {
 name   = "peering-hub-subnet-1"
 network = google_compute_network.hub-vpc.self_link

 allow {
   protocol = "all"
 }

 source_ranges = ["10.0.0.0/24", "10.10.0.0/24"]
 destination_ranges = ["10.200.0.0/24"]

 direction  = "INGRESS"
 priority   = 1000
 description = "Allow communication ingress comms between the peered subnets"

 log_config {
   metadata = "INCLUDE_ALL_METADATA"
 }
}

# Create Firewall rules for the Spoke VPC

resource "google_compute_firewall" "spoke-intra-fw" {
 name   = "intra-spoke-subnets"
 network = google_compute_network.spoke-vpc.self_link

 allow {
   protocol = "all"
 }

 source_ranges = ["10.0.0.0/24", "10.10.0.0/24"]
 destination_ranges = ["10.0.0.0/24", "10.10.0.0/24"]

 direction  = "INGRESS"
 priority   = 1000
 description = "Allow intra-subnets traffic"

 log_config {
   metadata = "INCLUDE_ALL_METADATA"
 }
}

########################################################

resource "google_compute_firewall" "spoke-iap-fw" {
 name   = "iap-spoke-subnets"
 network = google_compute_network.spoke-vpc.self_link

 allow {
   protocol = "TCP"
   ports = ["22"]
 }

 source_ranges = ["35.235.240.0/20"]
 destination_ranges = ["10.0.0.0/24", "10.10.0.0/24"]

 direction  = "INGRESS"
 priority   = 1000
 description = "Allow IAP for browser SSH"

 log_config {
   metadata = "INCLUDE_ALL_METADATA"
 }
}

########################################################

resource "google_compute_firewall" "spoke-peering-fw" {
 name   = "peering-spoke-subnets"
 network = google_compute_network.spoke-vpc.self_link

 allow {
   protocol = "all"
 }

 source_ranges = ["10.200.0.0/24"]
 destination_ranges = ["10.0.0.0/24", "10.10.0.0/24"]

 direction  = "INGRESS"
 priority   = 1000
 description = "Allow communication ingress comms between the peered subnets"

 log_config {
   metadata = "INCLUDE_ALL_METADATA"
 }
}

# Create a Router for Hub VPC

resource "google_compute_router" "hub-router" {
 name   = "hub-router"
 region = "europe-west2"
 network = google_compute_network.hub-vpc.self_link

 bgp {
  asn = 64513
  advertise_mode    = "CUSTOM"

  advertised_ip_ranges {
    range = "10.200.0.0/24"
  }
 }
}

# Create a Router for Spoke VPC

resource "google_compute_router" "spoke-router" {
 name   = "spoke-router"
 region = "europe-west2"
 network = google_compute_network.spoke-vpc.self_link

 bgp {
  asn = 64514
  advertise_mode    = "CUSTOM"

  advertised_ip_ranges {
    range = "10.0.0.0/24"
  }

  advertised_ip_ranges {
    range = "10.10.0.0/24"
  }
 }
}

# Create a NAT for Hub VPC

resource "google_compute_router_nat" "hub-nat" {
 router = google_compute_router.hub-router.name 
 region = "europe-west2"

 name = "hub-nat"
 enable_dynamic_port_allocation      = true
 nat_ip_allocate_option           = "AUTO_ONLY"
 min_ports_per_vm                = 64

source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.hub-subnet-1.name
    source_ip_ranges_to_nat = [google_compute_subnetwork.hub-subnet-1.ip_cidr_range]
  }

 log_config {
 enable = true
 filter = "ALL"
 }
}

# Create a NAT for Spoke VPC

resource "google_compute_router_nat" "spoke-nat" {
 router = google_compute_router.spoke-router.name 
 region = "europe-west2"

 name = "spoke-nat"
 enable_dynamic_port_allocation      = true
 nat_ip_allocate_option           = "AUTO_ONLY"
 min_ports_per_vm                = 64

source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.spoke-subnet-1.name
    source_ip_ranges_to_nat = [google_compute_subnetwork.spoke-subnet-1.ip_cidr_range]
  }

  subnetwork {
    name                    = google_compute_subnetwork.spoke-subnet-2.name
    source_ip_ranges_to_nat = [google_compute_subnetwork.spoke-subnet-2.ip_cidr_range]
  }

 log_config {
 enable = true
 filter = "ALL"
 }
}

# Create the backend VM fo Hub VPC subnet

resource "google_compute_instance" "hub-vm" {
 name        = "hub-vm-backend"
 machine_type = "e2-medium"
 zone        = "europe-west2-a"

 tags = ["hubvm"]

 boot_disk {
  initialize_params {
    image = "debian-cloud/debian-11"
    size = 10
  }
 }

 network_interface {
  network = google_compute_network.hub-vpc.self_link
  subnetwork = google_compute_subnetwork.hub-subnet-1.self_link
  network_ip = "10.200.0.2"
 }

 scheduling {
  preemptible = false
  automatic_restart = true
 }

 labels = {
  hub = "backend"
 }

 can_ip_forward = true

 metadata_startup_script = "apt install apache2 -y; apt install tcpdump -y; sysctl -w net.ipv4.ip_forward=1"

 service_account {
  email = "default"
  scopes = ["cloud-platform"]
 }

 hostname = "hubvm.internal"
}

# Create 2 VM for each Spoke VPC subnet

resource "google_compute_instance" "spoke-vm-s1" {
 name        = "spoke-vm-s1"
 machine_type = "e2-medium"
 zone        = "europe-west2-a"

 tags = ["spokevm1"]

 boot_disk {
  initialize_params {
    image = "debian-cloud/debian-11"
    size = 10
  }
 }

 network_interface {
  network = google_compute_network.spoke-vpc.self_link
  subnetwork = google_compute_subnetwork.spoke-subnet-1.self_link
  network_ip = "10.0.0.2"
 }

 scheduling {
  preemptible = false
  automatic_restart = true
 }

 labels = {
  spoke = "s1"
 }

 can_ip_forward = true

 metadata_startup_script = "apt install apache2 -y; apt install tcpdump -y; sysctl -w net.ipv4.ip_forward=1"

 service_account {
  email = "default"
  scopes = ["cloud-platform"]
 }

 hostname = "spokevms1.internal"
}

################################################

resource "google_compute_instance" "spoke-vm-s2" {
 name        = "spoke-vm-s2"
 machine_type = "e2-medium"
 zone        = "europe-west2-a"

 tags = ["spokevm2"]

 boot_disk {
  initialize_params {
    image = "debian-cloud/debian-11"
    size = 10
  }
 }

 network_interface {
  network = google_compute_network.spoke-vpc.self_link
  subnetwork = google_compute_subnetwork.spoke-subnet-2.self_link
  network_ip = "10.10.0.2"
 }

 scheduling {
  preemptible = false
  automatic_restart = true
 }

 labels = {
  spoke = "s2"
 }

 can_ip_forward = true

 metadata_startup_script = "apt install apache2 -y; apt install tcpdump -y; sysctl -w net.ipv4.ip_forward=1"

 service_account {
  email = "default"
  scopes = ["cloud-platform"]
 }

 hostname = "spokevms2.internal"
}

# Create an unmanaged Instance Group with Hub backend VM

resource "google_compute_instance_group" "hub-uig" {
  name        = "hub-uig"
  description = "Unmanaged Instance Group with Hub backend VM"

  instances = [
    google_compute_instance.hub-vm.self_link
  ]

  zone = "europe-west2-a"
}

# Create the Health check for the backend VM

resource "google_compute_health_check" "hub-health-check" {
  name        = "hub-hc"
  description = "Health check via http"

  timeout_sec         = 1
  check_interval_sec  = 1
  healthy_threshold   = 2
  unhealthy_threshold = 5

  http_health_check {
    port               = "80"
    host               = google_compute_instance.hub-vm.network_interface[0].network_ip
    request_path       = "/"
  }

log_config {
    enable = true
    }
}


# Create the Backend Service

resource "google_compute_region_backend_service" "hub-backend-service" {
  provider              = google-beta
  region                = "europe-west2"
  name                  = "hub-backend-service"
  health_checks         = [google_compute_health_check.hub-health-check.self_link]
  protocol              = "UNSPECIFIED"
  load_balancing_scheme = "INTERNAL"
  network = google_compute_network.hub-vpc.self_link
  backend {
    group = google_compute_instance_group.hub-uig.self_link
    }
  log_config {
   enable            = true
   sample_rate       = 1 
   }
}

# Create the forwarding rule

resource "google_compute_forwarding_rule" "hub-fwd" {
  provider        = google-beta
  region          = "europe-west2"
  name            = "l3-forwarding-rule"
  load_balancing_scheme = "INTERNAL"
  network = google_compute_network.hub-vpc.self_link
  subnetwork = google_compute_subnetwork.hub-subnet-1.self_link
  backend_service = google_compute_region_backend_service.hub-backend-service.self_link
  ip_protocol     = "L3_DEFAULT"
  all_ports       = true
  allow_global_access = true
}

# Create a policy based route

resource "google_compute_route" "route-ilb" {
  provider     = google-beta
  name         = "route-ilb"
  dest_range   = "10.0.0.0/8"
  network      = google_compute_network.spoke-vpc.name
  next_hop_ilb = google_compute_forwarding_rule.hub-fwd.self_link
  priority     = 1000
  

  depends_on = [
    google_compute_forwarding_rule.hub-fwd
  ]
}
