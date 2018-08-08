#!/bin/bash
set -eu

fly -t $TARGET execute --config <(cat <<EOF
---
platform: linux
image_resource:
  type: docker-image
  source:
    repository: governmentpaas/awscli
    tag: 895cf6752c8ec64af05a3a735186b90acd3db65a
run:
  path: sh
  args:
    - -e
    - -c
    - -u
    - |
      $@
EOF
)
