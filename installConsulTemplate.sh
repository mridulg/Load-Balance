#!/bin/bash
VERSION=0.16.0
curl -Lk https://github.com/hashicorp/consul-template/releases/download/v${VERSION}/consul-template_${VERSION}_darwin_amd64.tar.gz| tar -xz && mv consul-template_${VERSION}_darwin_amd64/consul-template /usr/local/bin/ && rm -rf consul-template_${VERSION}_darwin_amd64/
