# Terraform-GCP-Playgrounds

Repository to create basic architecture playgrounds.

Each section will show the source terraform code, and which resources will be deployed. 

To setup Terraform in your environment, the following series of videos on Youtube are short and concise [[1] Set up Terraform](https://www.youtube.com/watch?v=nvV6yobU710&list=PLpZQVidZ65jO_wtOpLv-HmC9uJgTRB8GT)|
|---|


---

## Playgrounds Index

### 1.- Global external Application Load Balancer // [Official Documentation](https://cloud.google.com/load-balancing/docs/https)
|[Source main.tf file](https://github.com/Miqquelangel/Terraform-GCP/blob/maste/Global%20external%20Application%20Load%20Balancer/main.tf)|
|---|

#### How to apply
* In order to execute the source "main.tf" file, first create a directory, access it and create the main.tf, execute "terraform init" and finally "terraform apply"; or you can execute the code below for the same results:
```bash
mkdir playgrounds 
cd playgrounds 
wget -O main.tf https://raw.githubusercontent.com/Miqquelangel/Terraform-GCP/maste/Global%20external%20Application%20Load%20Balancer/main.tf
```
* Then, modify the "main.tf" file with the data of your project:
```terraform
provider "google" {
 project = "Your_project_id" #Example: project = "project_whatever"
 region = "europe-west2"
}
```
* Finally, initialize and apply the terraform code:
```bash
terraform init
terraform apply
```
#### Overview

* Playground that will create a Global external HTTP Application Load Balancer on port 80.
* The backend of the LB will be an instance running as a NEG (Network Endpoint Group).
* It will create a VM, so you can communicate and make requests to the LB. The VM does not have External IP, therefore, a Cloud Router and NAT gateway will be deployed as well to communicate to the Internet.
* The FW rules are already configured to allow all egress comms, intra-VPC ingress comms, IAP ingress comms to allow SSH from the browser and to allow healthcheck ingress probes to our LB backend.
  
#### _Resources that will be deployed:_

* VPC
  
VPC name | Subnet name| Subnet region | Range(s) | MTU | PGA |
--- | --- | --- | --- | --- | --- |
`vpc-1` | `subnet-1` | `europe-west2` | `10.0.0.0/24` | `1460` | `Enabled` | 

* Firewall

FW rule | Direction | Priority | Protocol | Target | Source | Destination | Logging | Description |
--- | --- | --- | --- | --- | --- | --- | --- | --- |
`intra` | `INGRESS` | `1000` | `ALL` | `All instances in the VPC` | `["10.0.0.0/24"]` | `["10.0.0.0/24"]` | `Enabled` | `Allow intra-VPC traffic` | 
`iap` | `INGRESS` | `1000` | `TCP:22` | `All instances in the VPC` | `["35.235.240.0/20"]` | `["10.0.0.0/24"]` | `Enabled` | `Allow IAP for browser SSH` | 
`healthcheck` | `INGRESS` | `1000` | `TCP:80` | `Target Tag:[nginx]` | `["35.191.0.0/16", "130.211.0.0/22"]` | `Target Tag:[nginx]` | `Enabled` | `Allow healthcheck` | 

* Router
  
Router name | Region | BGP | Advertised ranges |
--- | --- | --- | --- |
`router- 1` | `europe-west2` | `ASN:64513 / Advertise_mode:CUSTOM` | `["10.0.0.0/24", "10.100.0.0/24"]` |

* NAT gateway
  
NAT name | Router | Region | Dynamic Port Allocation | NAT IP allocation | Minimum port per VM | Subnets to NAT | Logging |
--- | --- | --- | --- | --- | --- | --- | --- |
`nat-vpc1` | `router-1` | `europe-west2` | `Enabled` | `AUTO_ONLY` | `64` | `Subnet:"subnet-1", ["10.0.0.0/24"]` | `Enabled` |

* VMs
  
VM name | Machine type | Zone | OS / Boot disk | Networking | Tags | Labels | IP forwarding | Hostname | Metadata startup script | Service account | 
--- | --- | --- | --- | --- | --- | --- | --- |--- | --- | --- |
`mgmt-vpc1` | `e2-medium` | `europe-west2-a` | `debian-cloud/debian-11, size:10GB` | `Internal IP:"10.0.0.10", External IP:"NONE"` | `mgmtvpc1` | `mgmt = "vpc-1"` | `Enabled` | `"mgmt-vpc1.internal"` | `"apt install apache2 -y; apt install tcpdump -y"` | `Default compute SA, scopes=["cloud-platform"]` | 
`nginx-backend-neg-vpc1` | `e2-medium` | `europe-west2-a` | `debian-cloud/debian-11, size:10GB` | `Internal IP:"10.0.0.11", External IP:"NONE"` | `nginx` | `backend = "nginx"` | `Enabled` | `"backend-nginx-neg-vpc1.internal"` | `"apt install apache2 -y; apt install tcpdump -y; echo 'tusmuertos' > /var/www/html/index.html"` | `Default compute SA, scopes=["cloud-platform"]` | 

* NEG
  
NEG name | Network | Subnet | Port | Zone | VM name | Endpoint |
--- | --- | --- | --- | --- | --- | --- |
`nginx-neg` | `vpc-1` | `subnet-1` | `TCP:80` | `europe-west2-a` | `mgmt-vpc1` | `["10.0.0.11:80"]` |

* Health check
  
Health check name | Protocol | Host | Port | Path | Timeout | Check interval | Healthy threshold | Unhealthy threshold | Logging |
--- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
`nginx-hc` | `HTTP` | `["10.0.0.11"]` | `80` | `/` | `1 second` | `1 second` | `2` | `5` | `Enabled` |

* Backend service
  
Backend service name | Protocol | Timeout | Load balancing scheme | Session affinity | Custom resquest header | Custom response header | Backend NEG | Balancing mode | Health check name | Logging |
--- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---|
`backend-1` | `HTTP` | `10 second` | `EXTERNAL_MANAGED` | `HTTP_COOKIE` | `["host: jaja"]` | `["lala: lala"]` | `nginx-neg` | `"RATE":1000 per endpoint` | `nginx-hc` | `Enabled` |

* Load Balancer 

URL map name (Name of the Load Balancer) | Protocol  | IP:Port | HTTP keepalive timeout | Routing rules (Hosts;Paths;Backend) |
--- | --- | --- | --- | --- |
`urlmap` | `HTTP` | `"Unknown_until_deployment":80` | `610 second` | `["mysite.com;/home;backend-1"], ["mysite.com;/*;backend-1"], ["All unmatched;All unmatched;backend-1"]` |
</details>
