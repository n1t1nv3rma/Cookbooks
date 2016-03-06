#
# Cookbook Name:: deploy_ecs_server
# Recipe:: default
#
# Summary: 
# 	- Use this recipe to perform ECS Service deployment or rolling updates across the ECS cluster 
# Note: 
# 	- It is strongly advisable to test this recipe in your test/stg environments before implementing in prod. 
#       - Author is not responsible for any loss incurred or occurred by using this recipe.
# 	- Refer to README.md for more info.

search("aws_opsworks_app").each do |app|
  Chef::Log.info("********** The app's short name is '#{app['shortname']}' **********")
  Chef::Log.info("********** The app's URL is '#{app['app_source']['url']}' **********")

  if !( app[:environment_variables][:DEPLOY_ECS].eql?("true") )
    Chef::Log.info("Skipping deploy:: application #{app['name']} - does not have var DEPLOY_ECS to true")
    next
  else 
   app_path = "/srv/#{app['shortname']}"
    
   application app_path do
     environment.update(app["environment"])

    git app_path do
     repository app["app_source"]["url"]
     revision app["app_source"]["revision"]
    end

 bash "Deploying ECS Services in the #{app_path}/services via #{node[:opsworks][:instance][:hostname]}" do
  region = "#{node[:opsworks][:instance][:region]}"
  cwd = "#{app_path}/services"
  logfile = "/var/tmp/ow-ecs-service-deploy.log"
  user "root"
  code <<-EOH
echo "===========NEW RUN================" >> "#{logfile}"

# Functions
update_Task_Def_and_Count() {
  echo "`date`: Updating both Task Def and Desired Count now..."
  aws ecs update-service --cluster "${CLUST}" --service "${SVC}" --task-definition "${NEW_TDEF}"  --desired-count ${DCOUNT} --region="#{region}" >> "#{logfile}"
}
wait_for_steady() {
 until `aws ecs describe-services --cluster "${CLUST}" --service "${SVC}" --region="#{region}" | grep message | head -1 | grep "reached a steady state" >/dev/null 2>&1`
 do
   echo "`date`: Waiting for service to reach a steady state after deploying new service..."; sleep 5;
 done
}
# To enable debug uncomment following line
set -x
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
      update_Task_Def_and_Count;
      sleep 60;
      wait_for_steady;
      echo "`date`: Service: ${SVC} updated with new count ${DCOUNT} and new task def ${NEW_TDEF}..."
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
  rm -f /var/tmp/ecs-services.tmp
  echo "----------- Done with: ${SER_FILE} -------------"
 done >> "#{logfile}" 2>&1
 echo `date`: All done! Detailed LOGS are in "#{logfile}". >> "#{logfile}"
EOH
  only_if { ::File.exist?("/usr/bin/aws") }
 end

  end
end
