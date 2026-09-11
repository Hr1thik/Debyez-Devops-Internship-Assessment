#!/usr/bin/env bash
set -e

TAG=$1
if [ -z "$TAG" ]; then
  echo "Usage: ./deploy.sh <commit-sha>"
  exit 1
fi

PREV_TAG=""
if [ -f .current_version ]; then
  PREV_TAG=$(cat .current_version)
elif [ -f .env ]; then
  PREV_TAG=$(grep -E '^IMAGE_TAG=' .env | cut -d '=' -f 2)
fi

if [ -n "$PREV_TAG" ] && [ "$PREV_TAG" != "$TAG" ]; then
  echo "$PREV_TAG" > .previous_version
fi

echo "Targeting deployment version: $TAG"

if ! IMAGE_TAG="$TAG" docker compose -f docker-compose.prod.yml pull; then
  echo "Docker pull failed for tag $TAG! Triggering rollback..."
  ./rollback.sh
  exit 1
fi

sed -i "s/^IMAGE_TAG=.*/IMAGE_TAG=$TAG/" .env || echo "IMAGE_TAG=$TAG" >> .env
echo "$TAG" > .current_version

if ! docker compose -f docker-compose.prod.yml up -d; then
  echo "Docker compose up failed! Triggering rollback..."
  ./rollback.sh
  exit 1
fi

echo "Verifying health..."
sleep 10
if curl -sf http://api.debyez.localhost/api/health/full; then
  echo "Deployment successful."
else
  echo "Deployment failed. Triggering rollback..."
  ./rollback.sh
  exit 1
fi