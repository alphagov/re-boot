### naive hub helm template

* First pass at creating kubeyaml to run a Verify journey
* Has a bunch of compiled configmaps for pki bundled in
* Has lots of hardcoded stuff still
* only works for local until the localhost is templated out
* needs testrp/hub/idp split into sub charts
* needs ingress
* so
* many
* things
* wrong

Do not use with Tiller, just use as a templating thing:

```
helm template --kube-version 1.11 --namespace hub --name verify-hub --values local.yaml . | kubectl apply -f -
```
