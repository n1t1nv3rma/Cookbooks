#
# Cookbook Name:: deploy_ecs_server
# Recipe:: default
# Depends upon: OpsWorks default 'deploy' recipe
#
# Summary: 
# 	- Use this recipe to perform ECS Service deployment or rolling updates across the ECS cluster 
# Note: 
# 	- It is strongly advisable to test this recipe in your test/stg environments before implementing in prod. 
#       - Author is not responsible for any loss incurred or occurred by using this recipe.
# 	- Refer to README.md for more info.

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
# To enable debug uncomment following line
#set -x
echo "===========NEW RUN================" >> "#{logfile}"

# Functions
update_Task_Def() {
  echo "`date`: Updating Task Def now..."
  aws ecs update-service --cluster "${CLUST}" --service "${SVC}" --task-definition "${NEW_TDEF}" --region="#{region}" >> "#{logfile}"
}
update_Count_toDesired() {
  echo "`date`: Updating Desired Count now..."
  aws ecs update-service --cluster "${CLUST}" --service "${SVC}" --desired-count ${DCOUNT} --region="#{region}" >> "#{logfile}"
}
update_Task_Def_and_Count() {
  echo "`date`: Updating both Task Def and Desired Count now..."
  aws ecs update-service --cluster "${CLUST}" --service "${SVC}" --task-definition "${NEW_TDEF}"  --desired-count ${DCOUNT} --region="#{region}" >> "#{logfile}"
}
temp_reduce_Count() {
  echo "`date`: Temporarily reducing the Count now..."
  TCOUNT=`expr $TASKS - 1`
  aws ecs update-service --cluster "${CLUST}" --service "${SVC}" --desired-count ${TCOUNT} --region="#{region}" >> "#{logfile}"
}
wait_for_steady() {
 until `aws ecs describe-services --cluster "${CLUST}" --service "${SVC}" --region="#{region}" | grep message | head -1 | grep "reached a steady state" >/dev/null 2>&1`
 do
   echo "`date`: Waiting for service to reach a steady state after deploying new service..."; sleep 5;
 done
}
# Main goes here
 cd "#{cwd}" && for SER_FILE in `ls`; 
 do 
  echo "`date`: Deploying Service ${SER_FILE}...";
  SVC=`grep serviceName ${SER_FILE} | awk -F'"' '{print $4}'` ; 
  CLUST=`grep cluster ${SER_FILE} | awk -F'"' '{print $4}'`;
  DCOUNT=`grep desiredCount ${SER_FILE} | awk -F':' '{print $2}' | sed -e 's/,//'`;
  NEW_TDEF=`grep taskDefinition ${SER_FILE} | awk -F'"' '{print $4}'`;
  # Get current services
  aws ecs list-services --cluster ${CLUST} --region="#{region}" --output text > /var/tmp/ecs-services.tmp
  LIST_SVC_STAT="$?"
  SVC_RUNNING=`cat /var/tmp/ecs-services.tmp | cut -d'/' -f2 | grep -x "${SVC}"`

  if [ "${SVC}" != "" ] && [ "${CLUST}" != "" ] && [ "${DCOUNT}" != "" ] && [ "${NEW_TDEF}" != "" ]
    then
  # Check if service exist
  if [ "${SVC_RUNNING}" != "" ]
    then 
      echo "`date`: Service: ${SVC} already existing, updating it..."; 
      echo "`date`: Current issues: check for the need to prepare for rolling update!"
      # Get current tasks
      aws ecs list-tasks --output text --cluster  ${CLUST} --service ${SVC} --region="#{region}" > /var/tmp/ecs-tasks.tmp
      TASKS=`cat /var/tmp/ecs-tasks.tmp | grep arn | wc -l`
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
              echo "`date`: Tasks are less than Desired count..."
              update_Task_Def;
              echo "`date`: Waiting for service to reach a steady state..."
              sleep 60;
              wait_for_steady;
              update_Count_toDesired;
            elif [ $TASKS -eq $DCOUNT ]
            then
              echo "`date`: Tasks are equal to Desired count! So checking existing Task Def now..."
              TASK=`cat /var/tmp/ecs-tasks.tmp | grep arn | cut -d'/' -f2 | head -1`
              aws ecs describe-tasks --cluster ${CLUST} --region="#{region}" --tasks ${TASK} > /var/tmp/ecs-task-def.tmp
              CURR_TASK_DEF=`cat /var/tmp/ecs-task-def.tmp  | grep task-definition  | cut -d'/' -f2 | sed -e 's/"//' -e 's/,//'`
              CURR_TASK_DEF=`expr $CURR_TASK_DEF`
              if [ "${NEW_TDEF}" != "${CURR_TASK_DEF}" ]
                then
                  temp_reduce_Count;
                  update_Task_Def;
                  echo "`date`: Waiting for service to reach a steady state..."
                  sleep 60;
                  wait_for_steady;
                  update_Count_toDesired;
                else
                  echo "`date`: Current Task Def and Desired Count are same! SKIPPING ${SVC}..."
              fi
            else
              echo "Tasks are more than Desired count..."
              update_Count_toDesired;
              echo "`date`: Waiting for service to reach a steady state..."
              sleep 60;
              wait_for_steady;
              update_Task_Def;
          fi
       fi
     elif [ $LIST_SVC_STAT -eq 0 ]
      then
        echo "`date`: Service: ${SVC} is not running currently, deploying new service..."
        aws ecs create-service --cli-input-json file://${SER_FILE} --region="#{region}"
     else 
        echo "Error: Problem getting list of current services. Ensure region and cluster name are correct!"
    fi
  else 
    echo "Error: Problem getting required values from the ECS Service file: ${SER_FILE} !"
  fi
  rm -f /var/tmp/ecs-services.tmp /var/tmp/ecs-tasks.tmp /var/tmp/ecs-task-def.tmp
  echo "----------- Done with: ${SER_FILE} -------------"
 done | tee -a "#{logfile}" 2>&1
 echo `date`: All done! Detailed LOGS are in "#{logfile}".
EOH
  only_if { ::File.exist?("/usr/bin/aws") }
 end

end
