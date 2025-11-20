1.convert node.js file package.json using npm init 
2.Create Dockerfile for each services
3.Configure AWS credentils in the Github actions pipeline or in vault and pass it is variables.
4.Run the terraform pipeline for Init / Fmt / Validate / Plan / Apply that will create infra (iam , vpc, eks ,ecr,s3+dynamodb) 
5.login to aws ecr repo by configuring the credentils in github ci-cd pipeline.
6.build , tag and push the docker image .
7.deploy the service from the pipeline using manifest files by updating the image tags .
8.monitoring aspects still in progress.
