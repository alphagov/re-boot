#!/bin/bash

(cd data && for f in $(find .); do echo "$(echo $f) $(base64 --input $f)"; done | ruby -ryaml -e 'cfg={"apiVersion" => "v1", "kind" => "ConfigMap", "metadata" => {"name" => "verify-data"}, "binaryData" => {} }; h=cfg["binaryData"]; STDIN.read.each_line{|line| keys,value=line.split(" "); h[keys.sub(/^.\//,"").gsub("/","-")] = value if value}; puts cfg.to_yaml') > kompose/data.yaml
