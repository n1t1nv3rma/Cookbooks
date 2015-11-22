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

 bash "Deploying ECS Services in the #{deploy[:deploy_to]}/current/services via #{node[:opsworks][:instance][:hostname]}" do
  region = "#{node[:opsworks][:instance][:region]}"
  cwd = "#{deploy[:deploy_to]}/current/services"
  logfile = "/var/tmp/ow-ecs-service-deploy.log"
  user "root"
  code <<-EOH
set -x
update_Task_Def() {
  echo "`date`: Updating Task Def now..."
  aws ecs update-service --cluster "${CLUST}" --service "${SVC}" --task-definition "${TDEF}" --region="#{region}"
}
update_Count_toDesired() {
  echo "`date`: Updating Desired Count now..."
  aws ecs update-service --cluster "${CLUST}" --service "${SVC}" --desired-count ${DCOUNT} --region="#{region}"
}
update_Task_Def_and_Count() {
  echo "`date`: Updating both Task Def and Desired Count now..."
  aws ecs update-service --cluster "${CLUST}" --service "${SVC}" --task-definition "${TDEF}"  --desired-count ${DCOUNT} --region="#{region}"
}
temp_reduce_Count() {
  echo "`date`: Temporarily reducing the Count now..."
  TCOUNT=`expr $TASKS - 1`
  aws ecs update-service --cluster "${CLUST}" --service "${SVC}" --desired-count ${TCOUNT} --region="#{region}"
}
wait_for_steady() {
 until `aws ecs describe-services --cluster "${CLUST}" --service "${SVC}" --region="#{region}" | grep message | head -1 | grep "reached a steady state" >/dev/null 2>&1`
 do
   echo "`date`: Waiting for service to reach a steady state after deploying new service..."; sleep 5;
 done
}
# Main goes here
 cd "#{cwd}" 
 for SER_FILE in `ls`; 
 do 
  echo "Deploying Service ${SER_FILE}...";
  SVC=`grep serviceName ${SER_FILE} | awk -F'"' '{print $4}'` ; 
  CLUST=`grep cluster ${SER_FILE} | awk -F'"' '{print $4}'`;
  DCOUNT=`grep desiredCount ${SER_FILE} | awk -F':' '{print $2}' | sed -e 's/,//'`;
  TDEF=`grep taskDefinition ${SER_FILE} | awk -F'"' '{print $4}'`;
  LIST_SVC=`aws ecs list-services --cluster ${CLUST} --region="#{region}" | cut -d'/' -f2 | sed -e 's/"//' -e 's/,//' | grep -x "${SVC}"`
  # Check if service exist
  if [ "${LIST_SVC}" != "" ]
    then 
      echo "`date`: Service: ${SVC} already existing, updating it..."; 
      echo "`date`: Current issues: check for the need to prepare for rolling update!"
      TASKS=`aws ecs list-tasks --cluster  ${CLUST} --service ${SVC} --region="#{region}" | grep arn | wc -l`
      TOTAL_TASKS=`expr $DCOUNT + $TASKS`
      INSTANCE=`aws ecs list-container-instances --cluster ${CLUST} --region="#{region}" | grep arn | wc -l`

      if [ $TOTAL_TASKS -le $INSTANCE ]
        then
          echo "`date`: No need to prepare, updating the Service ${SVC} now..."
          update_Task_Def_and_Count;
        else
          echo "`date`: Preparing for rolling update of the Service ${SVC} now..."
          if [ $TASKS -lt $DCOUNT ]
            then
              echo "Tasks are less than Desired count..."
              update_Task_Def;
              echo "`date`: Waiting for service to reach a steady state"
              sleep 60;
              wait_for_steady;
              update_Count_toDesired;
            elif [ $TASKS -eq $DCOUNT ]
            then
              echo "Tasks are equal to Desired count..."
              temp_reduce_Count;
              update_Task_Def;
              echo "`date`: Waiting for service to reach a steady state"
              sleep 60;
              wait_for_steady;
              update_Count_toDesired;
            else
              echo "Tasks are more than Desired count..."
              update_Count_toDesired;
              echo "`date`: Waiting for service to reach a steady state"
              sleep 60;
              wait_for_steady;
              update_Task_Def;
          fi
      fi
    else
     echo "`date`: Service: ${SVC} is not running currently, deploying new service..."
     aws ecs create-service --cli-input-json file://${SER_FILE} --region="#{region}"
  fi
  done >> "#{logfile}" 2>&1
EOH
  only_if { ::File.exist?("/usr/bin/aws") }
 end

end
