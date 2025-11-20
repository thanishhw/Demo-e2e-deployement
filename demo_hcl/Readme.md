convert node.js file package.json using npm init 
Create Dockerfile for each services
Configure AWS credentils in the Github actions pipeline or in vault and pass it is variables.
Run the terraform pipeline for Init / Fmt / Validate / Plan / Apply that will create infra (iam , vpc, eks ,ecr,s3+dynamodb) 
login to aws ecr repo by configuring the credentils in github ci-cd pipeline.
build , tag and push the docker image .
deploy the service from the pipeline using manifest files by updating the image tags .
monitoring aspects still in progress.
