# DODA 2026 Team 10 - Operation

This repository contains the necessary configuration to run and operate the services developed by DODA 2026 Team 10.

1. [Project Repositories](#project-repositories)
2. [Project Structure](#project-structure)
3. [Getting Started](#getting-started)
4. [Cleanup](#cleanup)


## Project Repositories
| Repository | Description |
| :--- | :--- |
| **[model-service](https://github.com/doda25-team10/model-service)** | Serves predictions from a trained ML model via a REST API. |
| **[app-service](https://github.com/doda25-team10/app-service)** | The main backend API service, built with Java. |
| **[app-frontend](https://github.com/doda25-team10/app-frontend)** | Frontend application that communicates with `app-service` via REST API. |
| **[lib-version](https://github.com/doda25-team10/lib-version)** | A lightweight library for managing and retrieving the application version. |
| **[operation](https://github.com/doda25-team10/operation)** | Orchestrates all services. |


-----

## Project Structure

* [docker-compose.yml](/docker-compose.yml): Defines and starts the Docker containers by retrieving the required images.
* `README.md`: Provides instructions for startup, usage, and general information about the project.
* [Local model/ folder](/model/): Contains the trained model files and prediction outputs used by the model-service.



## Getting Started

Use the following steps to startup the services.

### 1. Prerequisites
Make sure you have [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed on your machine.

(Local model/ folder containing prediction models in .joblib format)

### 2. Start the Containers
Open a terminal and navigate to the root folder of the **`operation`** repository.  
Then start the containers with:

```bash
docker-compose up
```

If you prefer to keep using the same terminal for other commands, run the containers in the background:

```bash
docker-compose up -d
```


### 3. Access service

If everything ran properly going to [http://localhost:8080](http://localhost:8080) should show a "Hello World!" page.



## Cleanup

To stop and remove the containers, run:

```bash
docker-compose down -v
```

To stop the containers temporarily while keeping them intact, run:
```bash
docker-compose down
```