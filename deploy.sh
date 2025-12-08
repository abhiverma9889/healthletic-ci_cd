#!/bin/bash

# Variables
DOCKER_USER="abhiverma9889"
IMAGE_NAME="healthletic"
TAG="v1"   # change if needed
NAMESPACE="ci"

echo "🚀 Starting deployment process..."

# 1️⃣ Build Docker image
echo "📦 Building Docker image..."
docker build -t $DOCKER_USER/$IMAGE_NAME:$TAG .

# 2️⃣ Login to Docker Hub
echo "🔐 Logging into Docker Hub..."
docker login || { echo "❌ Docker login failed"; exit 1; }

# 3️⃣ Push image
echo "📤 Pushing image to Docker Hub..."
docker push $DOCKER_USER/$IMAGE_NAME:$TAG || { echo "❌ Failed to push image"; exit 1; }

# 4️⃣ Update Kubernetes deployment image
echo "♻ Updating Kubernetes deployment image..."
kubectl set image deployment/backend backend=$DOCKER_USER/$IMAGE_NAME:$TAG -n $NAMESPACE

# 5️⃣ Apply K8s manifests (optional for 1st deploy)
echo "🛠 Applying manifest files..."
kubectl apply -f k8s/ -n $NAMESPACE

# 6️⃣ Wait for rollout
echo "⏳ Waiting for rollout..."
kubectl rollout status deployment/backend -n $NAMESPACE

# 7️⃣ Optional: port-forward test
echo "🔍 Running smoke test..."
kubectl port-forward svc/backend -n $NAMESPACE 8080:5000 &
sleep 5
curl -f http://localhost:8080/health || { echo "❌ Health check failed"; exit 1; }

echo "🎉 Deployment completed successfully!"
