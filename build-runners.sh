#!/bin/bash

# Build all language runner images
echo "🏗️  Building language runner images..."

# Build images
docker build -t coderunner-python ./docker/python
docker build -t coderunner-node ./docker/node
docker build -t coderunner-cpp ./docker/cpp
docker build -t coderunner-java ./docker/java
docker build -t coderunner-go ./docker/go
docker build -t coderunner-rust ./docker/rust

echo "✅ All language runner images built successfully!"