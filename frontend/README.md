# SmartQueue

SmartQueue is a web application for appointment scheduling and queue
management in small clinics.

## Current status

Day 1 baseline:

- PostgreSQL runs with Docker Compose
- Spring Boot backend connects to PostgreSQL
- Flyway migration runs successfully
- Backend health endpoint is available
- React frontend displays backend health

## Technology stack

- Java 21
- Spring Boot 3.5
- Maven
- PostgreSQL 17
- Flyway
- React
- TypeScript
- Vite
- Docker Compose

## Project structure

```text
smartqueue/
├── backend/
├── frontend/
├── docs/
├── compose.yaml
└── README.md