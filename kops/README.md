# Kops spike

You can spin up the infrastructure required for Kops and a new cluster inside it with:

## Creating

```
$ ./create-cluster.sh your-cluster
```

You can converge the cluster to a state with various add-ons (such as a dashboard) with the following:

```
$ ./converge-cluster.sh your-cluster
```

You will have to specify some secrets for the Logit stack that this cluster will log to. You will also have to run this script multiple times as Kubernetes seems to be unable to the dependencies between the various resources we are creating in the cluster.

## Authentication with Google (Optional)

You have to point the Kubernetes API servers at the correct OIDC URL and restart all the masters. You will also have to edit `mgmt/users.yaml` to include any Google users (and their roles). You can then run:

```
$./configure-users.sh your-cluster
```

You can then use something like [k8s-oidc-helper](https://github.com/micahhausler/k8s-oidc-helper) to generate tokens with:

```
k8s-oidc-helper -c /client/secrets/file/from/google/cloud.json
```

This should generate a block of YAML. You can dump everything under `users` into your `~/.kube/config` and change the `context` for your cluster to use this as the `user`.

You're aiming for something that looks like this:

```
context:
  cluster: # your cluster
  user: # your google account
  name: # your cluster
```

## Deleting

```
$ ./delete-cluster.sh your-cluster
```
