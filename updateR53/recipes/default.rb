#
# Cookbook Name:: updateR53
# Recipe:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.
include_recipe "route53"

route53_record "create a record" do
  name  node[:opsworks][:instance][:hostname] + '.ringabell.com.au'
  value Net::HTTP.get(URI.parse('http://169.254.169.254/latest/meta-data/public-ipv4'))
  type  "A"
  ttl   60
  zone_id               node[:dns_zone_id]
  aws_access_key_id     node[:dns_access_key]
  aws_secret_access_key node[:dns_secret_key]
  overwrite true
  action :create
end
