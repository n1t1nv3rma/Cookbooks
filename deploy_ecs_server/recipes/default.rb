#
# Cookbook Name:: deploy_ecs_server
# Recipe:: default
# Depends upon: OpsWorks default 'deploy' recipe
# Copyright (c) 2015 The Authors, All Rights Reserved.

include_recipe 'deploy'

node[:deploy].each do |application, deploy|
 
  if !( deploy[:application_type].eql?("other") && deploy[:environment_variables][:DEPLOY_ECS].eql?("true") )
    Chef::Log.info("Skipping deploy:: application #{application} - not a ECS app")
    next
  end

  opsworks_deploy_dir do
    user deploy[:user]
    group deploy[:group]
    path deploy[:deploy_to]
  end

  opsworks_deploy do
    deploy_data deploy
    app application
  end

 bash "Deploying ECS Services in #{deploy[:deploy_to]}/current/services on #{node[:opsworks][:instance][:hostname]}" do
  region = #{node[:opsworks][:instance][:region]}
  cwd = #{deploy[:deploy_to]}/current/services
  user "root"
  code <<-EOH
    sleep 10
    date >> /var/tmp/ow-ecs-run.out
    cd #{cwd} && for SER in `ls`; do echo "Deploying Service ${SER}..."; CONT=`grep containerName ${SER} | awk -F'"' '{print $4}'` ; if ( `docker ps | grep -v grep | grep ${CONT} >/dev/null 2>&1` ) ; then echo "Container: ${CONT} is running currently, deploying an update to the service..."; aws ecs update-service --cli-input-json file://${SER} --region=#{region}; else echo "Container: ${CONT} is not running currently, deploying new service..."; aws ecs create-service --cli-input-json file://${SER} --region=#{region}; fi; done >> /var/tmp/ow-ecs-run.out 2>&1
  EOH
  only_if { ::File.exist?("/usr/bin/docker") && !OpsWorks::ShellOut.shellout("docker ps -a").include?("amazon-ecs-agent") }
 end


end
