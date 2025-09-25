# Infrastructure Engineer Task

Hi Applicant!

Thanks for taking your time to work on this task.

Ideally this test should take 6 hours, but feel free to take as much time as you need, for us quality means more than speed, although, the latest delivery is one week starting now.

The main goal of this test is for us to get to know about your skills better, as well as for you to get to know our current workflow. The solution of the task is not too hard, so you can focus on technology and scripting, show us what you got :wink:

This is your demo, so overperforming is always very welcome!

## Todo
1. Create a new repository and push all content here into the `main` branch
2. Create a new branch
3. Please, make sure you use as many commits as you can, we would love to see your progress.
4. After finishing your work, create a Pull Request to `main`.
5. Be ready to answer questions


## Requirements
 * Keep a clean and understandable folder structure.
 * Document your work, we love comments and documentation.
 * Write all the documentation and comments in English.
 
---

## Your tasks:
1. Set up a local cluster with a monitoring and logging stack
   - You can find a `start-local.sh` script that starts a local kind and container registry, continue from that or do it in another way.
   - You have to provide the instructions/script to start it

2. Create a script to build and deploy the frontend and backend services unto your cluster.

3. Make the services observable

4. Integrate the monitoring stack with Pagerduty (or another incident alert service) to send alerts for critical events. Provide the settings and instructions to set up, the service account is not required

5. Update the README.md file with the steps to run everything

## Project description
[Guestbook](https://github.com/GoogleCloudPlatform/cloud-code-samples/tree/v1/python/python-guestbook) is a simple application consisting of 3 main services, the `frontend`, the `backend` and the `mongodb`. 

## Evaluation criteria

This is what we look at - among other things:
* The deployment flow has to run, please provide **short** setup instructions.
* The setup of the monitoring stack
* Automation.
* Metrics collected and alerting configuration

We wish you the best of lucks. :grin:

## Prerequisites
- Kind - If you want to use the local kind cluster which is setup in `start-local.sh` then you will have to download [kind](https://kind.sigs.k8s.io/docs/user/quick-start/)
- Docker running
