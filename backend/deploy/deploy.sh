#!/usr/bin/env bash
# Runs on the server (CI calls it over SSH): pull the API image for a commit
# and restart. Usage: deploy.sh <image>   e.g. ghcr.io/owner/peliculas-api:<sha>
set -euo pipefail
cd /opt/peliculas

image="${1:?usage: deploy.sh <image>}"
export API_IMAGE="$image" API_VERSION="${image##*:}"

docker compose pull api
docker compose --profile prod up -d --no-build --remove-orphans api caddy db
docker compose --profile prod up -d --build backup

for _ in $(seq 1 30); do
	status=$(docker inspect -f '{{.State.Health.Status}}' "$(docker compose ps -q api)")
	if [[ "$status" == healthy ]]; then
		echo "deploy: $image is healthy"
		docker image prune -f >/dev/null
		exit 0
	fi
	sleep 2
done
echo "deploy: $image did not become healthy" >&2
docker compose logs --tail 50 api >&2
exit 1
