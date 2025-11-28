# DODA 2026 Team 10 - Operation

This repository contains the necessary configuration to run and operate the services developed by DODA 2026 Team 10.

1. [Project Repositories](#project-repositories)
2. [Project Structure](#project-structure)
3. [Getting Started](#getting-started)
4. [Cleanup](#cleanup)

## Project Repositories

| Repository                                                             | Description                                                                |
| :--------------------------------------------------------------------- | :------------------------------------------------------------------------- |
| **[model-service](https://github.com/doda25-team10/model-service)** | Serves predictions from a trained ML model via a REST API.                 |
| **[app-service](https://github.com/doda25-team10/app-service)**     | The main backend API service, built with Java.                             |
| **[app-frontend](https://github.com/doda25-team10/app-frontend)**   | Frontend application that communicates with `app-service` via REST API.  |
| **[lib-version](https://github.com/doda25-team10/lib-version)**     | A lightweight library for managing and retrieving the application version. |
| **[operation](https://github.com/doda25-team10/operation)**         | Orchestrates all services.                                                 |

---

## Project Structure

* [docker-compose.yml](/docker-compose.yml): Defines and starts the Docker containers by retrieving the required images.
* `README.md`: Provides instructions for startup, usage, and general information about the project.
* [Local model/ folder](/model/): Includes the trained model files when using a custom model as well as the output of the trained model.

## Getting Started

Use the following steps to startup the services.

### 1. Prerequisites

Make sure you have [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed on your machine.

In case you are using a custom model, create a new folder called model in the current root folder with the following files:
- model.joblib
- preprocessor.joblib
- preprocessed_data.joblib


### 2. Start the Containers

Open a terminal and navigate to the root folder of the **`operation`** repository.
Then start the containers with:

```bash
docker compose up
```

If you prefer to keep using the same terminal for other commands, run the containers in the background:

```bash
docker compose up -d
```

### 3. Access service

If everything ran properly, going to http://localhost:8080 should show a page with "Hello World!" and the current library version.

To use the application go to http://localhost:8080/sms.

## Cleanup

To stop and remove both containers and images, run:

```bash
docker compose down --rmi all
```

---

To stop and remove the containers while leaving the images intact, run:

```bash
docker compose down 
```

---

To stop the containers temporarily while keeping them intact, run:

```bash
docker compose stop
```

---
How to check if the correct version of Conteinerd, runc and kubutel are downloaded:

Terminal 1:
```bash
vagrant up
vagrant provision 
```
(It should work for a bit and either give ok or changed for all of the tasks)

Terminal 2:
in the operation
```bash
Vagrant ssh ctrl
```
```bash
dpkg-query -W -f='${Version}\n' containerd 
``` 
This will show the version installed for containerd (should be 1.7.24)
```bash
dpkg-query -W -f='${Version}\n' runc 
```
This should also show the version installed for runc (should be1.1.12)
```bash
apt-cache policy kubelet
```
Here, it should print the version of the kubernetes (should be 1.32.4)
```bash
systemctl is-enabled kubelet 
```
It should return enabled

```bash
systemctl is-active kubelet 
```
Should return activating
## Comments for A2

We tried implementing steps up to and including Step 18 to match the Excellent criterion. 
