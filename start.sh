#!/bin/bash
sudo nginx
consul-template -consul=$CONSUL_URL -template="default.ctmpl:/etc/nginx/conf.d/default.conf:service nginx reload"
