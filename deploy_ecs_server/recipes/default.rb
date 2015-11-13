#
# Cookbook Name:: deploy_ecs_server
# Recipe:: default
#
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
end
