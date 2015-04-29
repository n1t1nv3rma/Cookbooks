#
# Cookbook Name:: unicorn_service
# Recipe:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

template "/etc/init.d/unicorn" do
  source "unicorn_service.erb"
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

link "/etc/rc3.d/S84unicorn" do
  action :create
  to "/etc/init.d/unicorn"
end

link "/etc/rc0.d/K16unicorn" do
  action :create
  to "/etc/init.d/unicorn"
end
