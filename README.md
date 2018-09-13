# RE-boot

Bootstrap the main kubernetes cluster to rule them all.

## Prerequisites

- [terraform 0.11.7](https://releases.hashicorp.com/terraform/0.11.7/terraform_0.11.7_darwin_amd64.zip) `brew install terraform`
- [kops](https://github.com/kubernetes/kops/releases/download/1.9.2/kops-darwin-amd64) `brew install kops`
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl) `brew install kubernetes-cli`
- [awscli](https://aws.amazon.com/cli/) `brew install awscli`
- AWS environment

## Usage

You should have a `DEPLOY_ENV` environment variable set.

Then, to deploy a new cluster, run:

```sh
make dev up
```

To tear it down, use:

```sh
make dev down
```

You can converge the cluster to a state with various add-ons (such as a
dashboard) with the following:

```sh
make dev converge
```
