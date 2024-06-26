#!/bin/bash

mkdir -p scripts

docker compose kill
docker compose rm -f
docker compose build
docker compose up -d
