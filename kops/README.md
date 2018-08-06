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

## Deleting

```
$ ./delete-cluster.sh your-cluster
```
