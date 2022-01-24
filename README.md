# Overview
This repo is for Blitz.gg Webhook Take Home Test specifically my implementation. You can read the requirements [here](Blitz_DevOps_Take_Home_Test.pdf). I documented my approach to each problem which can be found [here](My_Approach_to_Blitz_Webhook_Take_Home_Test.md)

# Technologies
- [Docker](https://docker.com): As container platform
- [Webhook](https://github.com/adnanh/webhook): As webhooks

# Local Setup
To setup the environment you need to run the `start-environment` script which will run docker-compose up to create the containers. To take down the environment run the `stop-environment` script which will run docker-compose down to stop and remove the containers. 

# Usage
Once the environment is setup you can run `append-text` which will prompt for a text file either full path or relative. You can use a custom text file or use the supplied exampleFile.txt for testing. 

You will then be prompted for the text you wish to append to end of the file. Once satisfied with the test you have entered press enter and after a short period if successful you will see a message saying as such. You will find your file with append text in the storage directory under the same name you entered. 

If you want to test this from inside the testContainer to make sure the endpoint works within docker networking please run `append-text-inside-container`. The prompts will be the same but you will need to enter "exampleFile.txt" as the txt file otherwise you will need to add a text file manually to the testContainer. 

# Summary of its workflow
When append-text is ran it take in values that the user passes in and validates them first if there are errors it will display them and exit. It will create a GET request to the get-token endpoint to get its authToken. get-token will validate that an authToken does not already exist for this IP and if it does respond back with it otherwise generate a new one, save it and respond with the authToken. 

Once it receives its authToken it will encode the users input in base64 and create a POST request to append-text endpoint. The payload will contain the encoded values for both the file and the user's text. The header of the request will contain the authToken previously gathered. The URL will also have a static token appended to end as a query. 

append-text will first validate that the static token is what it expect in the URL query. It will then validate that the authToken in the header is valid and exists in the "database". If both conditions are met it will then save the user's file in persistent storage with the appended text. 

# Warnings
I didn't test this on a Windows OS devices, I used WSL with ubuntu for my development. 

I expect the scripts to be ran from the root of the repo. If a script is not ran from the root it could error out although I believe I have taken precautions for that as well as provided errors for this. 

# Moving it to the cloud
If I were to move this project to AWS I would start off by using Terraform to assist in building the infrastructure like container registry (ECR), persistent storage (EFS or EBS), container orchestration (ECS or EKS), Networking (VPC and subnets). Once that is done I setup CI/CD for the containers to be built and uploaded to the container registry with tags using Github Actions. I would then use the Actions to deploy the container to my container orchestration using the tags either with task definitions or helm charts. Since I am not sure about how often this will be used and by who maybe a message queue could be added if there are alot for requests also setup auto scaling. I would also replace the authToken proccess I created with an actual product for that and use SSL for communication. 
