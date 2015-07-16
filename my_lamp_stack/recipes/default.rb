#
# Cookbook Name:: my_lamp_stack
# Recipe:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

# Get packages - Version??

pkgs = ["httpd","php"]
this_is_motd = "God Bless Ya!"

pkgs.each do |pkg|
  package pkg do
    action :install
  end
end

# Setup service
service 'httpd' do
   action [:enable, :start]
end

# Just plane files
cookbook_file "/var/www/html/index2.html" do
  source "index.html"
  mode 0644
  action :create_if_missing
end

# setup PHP file
cookbook_file "/var/www/html/info.php" do
  source "info.php"
  mode 0644
end

# Setup Static Content
template '/var/www/html/index.html' do
   source 'index.html.erb'
   variables(
      :motd => "this is the message mate!",
      :jvm => node['opsworks_java']['jvm'], 
      :version => node['opsworks_java']['jvm_version']
      )
   notifies :restart, resources(:service => 'httpd')
end

# Setup FW
service 'iptalbes' do
    action :stop
end

# Create directory
directory "#{ENV['HOME']}/test/tmp" do
    mode 0755
    owner 'root'
    group 'root'
    action :create
    recursive true
end
