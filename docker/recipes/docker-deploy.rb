# This recipe deploys your docker containers (specified by a Dockerfile)
include_recipe 'deploy'

node[:deploy].each do |application, deploy|

  if !( deploy[:application_type].eql?("other") && deploy[:environment_variables][:layer].eql?("dockerlayer") )
    Chef::Log.info("Skipping deploy:: application #{application} - not a docker app")
    next
  end

  if deploy[:environment_variables][:service_port] != "" && deploy[:environment_variables][:container_port] != ""
    Chef::Log.info("Proceeding with docker deploy for application #{application} ...")

  opsworks_deploy_dir do
    user deploy[:user]
    group deploy[:group]
    path deploy[:deploy_to]
  end

  opsworks_deploy do
    deploy_data deploy
    app application
  end

  bash "docker-cleanup" do
    user "root"
    code <<-EOH
      if docker ps | grep #{deploy[:application]}; 
      then
        docker stop #{deploy[:application]}
        sleep 3
        docker rm -f #{deploy[:application]}
        sleep 3
      fi
      if docker images | grep #{deploy[:application]}; 
      then
        docker rmi -f #{deploy[:application]}
      fi
    EOH
  end

  bash "docker-build" do
    user "root"
    cwd "#{deploy[:deploy_to]}/current"
    code <<-EOH
     docker build -t=#{deploy[:application]} . > #{deploy[:application]}-docker.out
    EOH
  end
  
  dockerenvs = " "
  deploy[:environment_variables].each do |key, value|
    dockerenvs=dockerenvs+" -e "+key+"="+value
  end
  
  bash "docker-run" do
    user "root"
    cwd "#{deploy[:deploy_to]}/current"
    code <<-EOH
      docker run #{dockerenvs} -p #{node[:opsworks][:instance][:private_ip]}:#{deploy[:environment_variables][:service_port]}:#{deploy[:environment_variables][:container_port]} --name #{deploy[:application]} -d #{deploy[:application]}
    EOH
   end
 end

end
