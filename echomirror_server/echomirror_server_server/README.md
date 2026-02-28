# echomirror_server_server

This is the starting point for your Serverpod server.

## Required environment variables

For video/voice calls (Agora), set these before running the server:

- **AGORA_APP_ID** – Agora project App ID
- **AGORA_APP_CERT** – Agora App Certificate

Copy `.env.example` to `.env` in this directory, fill in the values (from [Agora Console](https://console.agora.io/)), and load them when starting the server (e.g. `export $(cat .env | xargs)` then `dart bin/main.dart`).

## Running the server

To run your server, you first need to start Postgres and Redis. It's easiest to do with Docker.

    docker compose up --build --detach

Then you can start the Serverpod server.

    dart bin/main.dart

When you are finished, you can shut down Serverpod with `Ctrl-C`, then stop Postgres and Redis.

    docker compose stop
