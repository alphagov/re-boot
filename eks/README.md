# AWS EKS Spike

## Getting started

Create a bucket for your state. Probably something like this:

```
$ aws s3api create-bucket \
  --bucket gds-paas-k8s-shared-state \
  --region us-east-1 # --create-bucket-configuration LocationConstraint=us-east-1
```

Switch to a Terraform deployment:

```
$ cd deployments/sam
```

Apply Terraform manifets:

```
$ terraform init && terraform apply
```

Follow the [EKS Getting Started Guide](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html). Some of it is relevant, some of it is not. The following was interesting at the time of writing:

- You can use the stock `kubectl`.
- Configure `kubectl` work with `aws-iam-authenticator` (you can `go install` this if you want)
- The user authenticating against the cluster for the first time should be the same user that create the cluster (lol).
- You need to follow the `aws-auth` `ConfigMap` steps in order for nodes to be able to connect to the cluster (see: `mapRoles`). You have to copy and apply some random "stock" `ConfigMap` to make this work. The role you want to use is the `${DEPLOYMENT_NAME}-nodes` role.
- You need to follow the `aws-auth` `ConfigMap` steps if you want different IAM users to be able to do things (see: `mapUsers`).
- You can test you can connect with something like `kubectl api-resources`
