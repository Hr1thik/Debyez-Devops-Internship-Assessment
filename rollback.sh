#!/usr/bin/env bash
set -e

if [ ! -f .previous_version ]; then
  echo "Error: No previous version recorded."
  exit 1
fi

PREV_TAG=$(cat .previous_version)
echo "Rolling back to version: $PREV_TAG"
sed -i "s/^IMAGE_TAG=.*/IMAGE_TAG=$PREV_TAG/" .env
echo "$PREV_TAG" > .current_version

docker compose -f docker-compose.prod.yml up -d
echo "Rollback completed."