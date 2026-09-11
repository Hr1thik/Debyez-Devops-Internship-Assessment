#!/usr/bin/env bash
set -e

TAG=$1
if [ -z "$TAG" ]; then
  echo "Usage: ./deploy.sh <commit-sha>"
  exit 1
fi

if [ -f .env ]; then
  PREV_TAG=$(grep -E '^IMAGE_TAG=' .env | cut -d '=' -f 2)
  echo "$PREV_TAG" > .previous_version
fi

echo "Deploying version: $TAG"
sed -i "s/^IMAGE_TAG=.*/IMAGE_TAG=$TAG/" .env || echo "IMAGE_TAG=$TAG" >> .env
echo "$TAG" > .current_version

docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d

echo "Verifying health..."
sleep 10
if curl -sf http://api.debyez.localhost/api/health/full; then
  echo "Deployment successful."
else
  echo "Deployment failed. Rolling back..."
  ./rollback.sh
fi