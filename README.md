1. convert node.js file package.json using npm init 
2. Create Dockerfile for each services 
3. Run the clone pipeline 
4. Configure the aws credentils in the github pipeline or the scredentials manager and call in variables 
5. build the docker images from the pipeline using (docker build -f appointment.Dockerfile -t appointment-app .)
6. configure the ecr credentils 
7. push  the images to the ecr repo
8. run the github pipeline for deploying infra (eks, vpc, iam , s3 dynamodb)
9. deploy on eks from the pipeline using manifest file by updating the latest image tag .
