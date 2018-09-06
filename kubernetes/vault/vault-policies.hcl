path "secret/demo/*" {
    capabilities = ["create", "read", "update", "delete", "list"]
}

path "concourse/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
