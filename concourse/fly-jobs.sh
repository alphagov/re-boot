#!/bin/bash
set -eu

TARGET="cluster-name-irrelevant"
PIPELINES=$(fly -t $TARGET pipelines | awk '{print $1}')

for PIPELINE in $PIPELINES; do
    JOBS=$(fly -t $TARGET jobs -p $PIPELINE | awk '{print $4}')
    for [ JOB in $JOBS ]; do
        if $JOB != "n/a"; then
            echo "Something running"
        else
            echo "Nada running"
        fi
    done
done