module "kubernetes" {
  source = "scholzj/kubernetes/aws"

  aws_region    = "eu-west-2"
  cluster_name  = "rafalp-kubernetes"
  master_instance_type = "t2.medium"
  worker_instance_type = "t2.medium"
  ssh_public_key = "~/.ssh/id_rsa.pub"
  ssh_access_cidr = ["0.0.0.0/0"]
  api_access_cidr = ["0.0.0.0/0"]
  min_worker_count = 3
  max_worker_count = 6
  hosted_zone = "govsvc.uk"
  hosted_zone_private = false

  master_subnet_id = "${module.vpc.subnet_ids[0]}"
  worker_subnet_ids = ["${module.vpc.subnet_ids}"]
  
  tags = {
    Application = "Kubernetes"
  }

  tags2 = [
    {
      key                 = "Application"
      value               = "Kubernetes"
      propagate_at_launch = true
    }
  ]
  
  addons = [
    "https://raw.githubusercontent.com/scholzj/terraform-aws-kubernetes/master/addons/storage-class.yaml",
    "https://raw.githubusercontent.com/scholzj/terraform-aws-kubernetes/master/addons/heapster.yaml",
    "https://raw.githubusercontent.com/scholzj/terraform-aws-kubernetes/master/addons/dashboard.yaml",
    "https://raw.githubusercontent.com/scholzj/terraform-aws-kubernetes/master/addons/external-dns.yaml",
    "https://raw.githubusercontent.com/scholzj/terraform-aws-kubernetes/master/addons/autoscaler.yaml"
  ]
}
