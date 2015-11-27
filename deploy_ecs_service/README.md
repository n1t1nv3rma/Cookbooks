# deploy_ecs_service
- Developed by: vernitin@ 
- **Note:** It is strongly advisable to test this Chef recipe in your test/stg environments before implementing in prod. Author is not responsible for any loss incurred or occurred by using this recipe.
 
## Use this Chef Recipe to deploy AWS ECS Service(s) into an existing AWS ECS Cluster, as an AWS OpsWorks App.

## The OpsWorks App must be in specific format given below.

* Create a directory called "services" and place any number of files listing ECS Services in JSON format in it.
For Example: OpsWorks App structure will be:
 App:
  - services
    - my-ecs-service-1
    - my-ecs-service-2
    - my-ecs-service-3
     ...

* The content of the "services/my-ecs-service-1" file content must be in following standard JSON format compatible with AWS CLI.
**Note:** that all values must be valid as per your pre-existing ECS Task Definition.

```
{
   "cluster": "my-ow-ecs-cluster",
   "serviceName": "ecs-sample-service-elb",
   "taskDefinition": "my-sample-console:5",
   "loadBalancers": [
       {
         "loadBalancerName": "my-ow-ecs-elb",
         "containerName": "simple-app",
         "containerPort": 80
       }
     ],
   "desiredCount": 2
}
```

OR

```
{
   "cluster": "my-ow-ecs-cluster",
   "serviceName": "ecs-sample-service-non-elb",
   "taskDefinition": "my-2nd-task-def:6",
   "desiredCount": 1
}
```

## Deploy this App via OpsWorks on the instances running under ECS Cluster Layer!
- **To troubleshoot or find out details around the ECS deployments**, refer to the log file "/var/tmp/ecs-service-deploy.log" on the ECS container instance. 

