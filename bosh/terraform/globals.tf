variable "env" {
  description = "Environment name"
}

variable "region" {
  description = "AWS region"
}

variable "zones" {
  description = "AWS availability zones"
  type        = "map"
}

variable "zone_count" {
  description = "Number of zones to use"
}

variable "infra_cidrs" {
  description = "CIDR for infrastructure subnet indexed by AZ"

  default = {
    zone0 = "10.0.0.0/24"
    zone1 = "10.0.1.0/24"
    zone2 = "10.0.2.0/24"
  }
}

/* 
   Operators will mainly be from the office. 
   See [wiki][1] for details.

   [1]: https://sites.google.com/a/digital.cabinet-office.gov.uk/gds-internal-it/news/aviationhouse-sourceipaddresses
*/
variable "admin_cidrs" {
  description = "CSV of CIDR addresses with access to operator/admin endpoints"

  default = [
    "85.133.67.244/32",
    "213.86.153.212/32",
    "213.86.153.213/32",
    "213.86.153.214/32",
    "213.86.153.235/32",
    "213.86.153.236/32",
    "213.86.153.237/32",
  ]
}

variable "concourse_egress_cidr" {
  description = "Public egress IP address of concourse running the pipeline"
  default     = ""
}

variable "public_key" {
  description = "Public ssh key to be allowed access to the VM"
  default     = ""
}
