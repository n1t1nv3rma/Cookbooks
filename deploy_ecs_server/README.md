# deploy_ecs_server
- Developed by: vernitin@ 
- Use at your own risk.
 
## Use this recipe to deploy an AWS OpsWorks App into your AWS ECS Cluster

## The OpsWorks App must be in folowing format:

# Create a directory called "services" with any number of files listing ECS Services in JSON format
For Example: OpsWorks App structure will be:
 App:
  - services
    - my-ecs-service-1
    - my-ecs-service-2
    - my-ecs-service-3
     ...

## Create any number of files listing ECS Service under "services" folder.
- For Example: The content of the "services/my-ecs-service-1" file content must be in following standard JSON format compatible with AWS CLI

`
{
              "cluster": "my-ow-ecs-cluster",
              "serviceName": "ecs-sample-service-elb",
              "taskDefinition": "my-sample-console:4",
              "loadBalancers": [
                  {
                      "loadBalancerName": "my-ow-ecs-elb",
                      "containerName": "simple-app",
                      "containerPort": 80
                  }
              ],
              "desiredCount": 2,
              "role": "ecsServiceRole"
}
`

# Deploy this App via OpsWorks on the instances running under ECS Cluster Layer!
- **To troubleshoot or find out details around the ECS deployments**, refer to the log file "/var/tmp/ow-ecs-service-deploy.log" on the ECS container instance. 
