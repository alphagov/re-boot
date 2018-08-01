#
# EKS Cluster Resources
#  * IAM Role to allow EKS service to manage other AWS services
#  * EC2 Security Group to allow networking traffic with EKS cluster
#  * EKS Cluster
#

resource "aws_iam_role" "managed-cluster" {
  name = "${var.cluster_name}-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "managed-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.managed-cluster.name}"
}

resource "aws_iam_role_policy_attachment" "managed-cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.managed-cluster.name}"
}

resource "aws_security_group" "managed-cluster" {
  name        = "${var.cluster_name}-cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = "${aws_vpc.managed.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.cluster_name}"
  }
}

resource "aws_security_group_rule" "managed-cluster-ingress-node-https" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.managed-cluster.id}"
  source_security_group_id = "${aws_security_group.managed-node.id}"
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "managed-cluster-ingress-https" {
  cidr_blocks       = [
		"85.133.67.244/32",
		"213.86.153.212/32",
		"213.86.153.213/32",
		"213.86.153.214/32",
		"213.86.153.235/32",
		"213.86.153.236/32",
		"213.86.153.237/32",
	]
  description       = "Allow office IP ranges to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = "${aws_security_group.managed-cluster.id}"
  to_port           = 443
  type              = "ingress"
}

resource "aws_eks_cluster" "managed" {
  name     = "${var.cluster_name}"
  role_arn = "${aws_iam_role.managed-cluster.arn}"

  vpc_config {
    security_group_ids = ["${aws_security_group.managed-cluster.id}"]
    subnet_ids         = ["${aws_subnet.managed.*.id}"]
  }

  depends_on = [
    "aws_iam_role_policy_attachment.managed-cluster-AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.managed-cluster-AmazonEKSServicePolicy",
  ]
}
