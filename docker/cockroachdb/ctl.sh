#!/bin/bash

set -ue

ACTIVE_EXPRESSION='{{.State.Status}}'
ACTIVE_OK="running"
HEALTH_EXPRESSION='{{.State.Health.Status}}'
HEALTH_OK="healthy"

DATABASE_USER=${DATABASE_USER:-app}
DATABASE_PASSWORD=
DATABASE_NAME=${DATABASE_NAME:-defaultdb}
DATABASE_PORT=${DATABASE_PORT:-26257}

bin=$(which docker)
dir=$(cd "$(dirname "$0")" && pwd)

function docker() {
  echo " [debug] docker $@" >&2
  "$bin" "$@"
}

function destroy_environment() {
  echo "Destroying environment" >&2
  docker compose down -v
}

function stop_environment() {
  echo "Stopping environment" >&2
  docker compose down
}

function start_environment() {
  echo "Starting environment" >&2
  docker compose up -d

  wait_for_service "db1" "$ACTIVE_EXPRESSION" "$ACTIVE_OK"

  # Initialize the cluster if this is the first time
  if ! docker compose exec db1 test -e /cockroach/cockroach-data/.cluster-initialized; then
    echo "CockroachDB cluster has not been initialized. Initializing now." >&2
    docker compose exec db1 ./cockroach init --insecure
    docker compose exec db1 touch /cockroach/cockroach-data/.cluster-initialized
  fi

  wait_for_service "db1" "$HEALTH_EXPRESSION" "$HEALTH_OK"

  # Create the default user and grant access to the default database
  if ! docker compose exec db1 test -e /cockroach/cockroach-data/.database-initialized; then
    echo "CockroachDB database and user have not been created. Creating now." >&2
    echo "CREATE USER $DATABASE_USER;" | docker compose exec -T db1 ./cockroach sql --insecure >/dev/null 2>&1
    echo "GRANT admin TO $DATABASE_USER;" | docker compose exec -T db1 ./cockroach sql --insecure >/dev/null 2>&1
    docker compose exec db1 touch /cockroach/cockroach-data/.database-initialized
  fi

  display_environment_status
}

function display_environment_status() {
  local db_service_ok

  db_service_ok=$(is_service_healthy "db1")

  {
    echo
    echo ====================================================================================
    echo
    if [[ "$db_service_ok" -eq 1 ]]; then
      echo "[SUCCESS] CockroachDB is online. Use the following url to connect:"
      echo
      echo "DATABASE_URL=\"postgresql://$DATABASE_USER:$DATABASE_PASSWORD@localhost:$DATABASE_PORT/$DATABASE_NAME?schema=public\""
    else
      echo "[FAIL] CockroachDB is not online."
    fi
    echo
    echo ------------------------------------------------------------------------------------
    echo
    "$bin" compose ps -a
    echo
    echo ====================================================================================
    echo
  } >&2
}

function is_service_healthy() {
  local service=$1
  local container

  if [[ $# -gt 1 ]]; then
    container="$2"
  fi

  check_service "$service" "$HEALTH_EXPRESSION" "$HEALTH_OK" "$container"
}

function is_service_running() {
  local service=$1
  local container

  if [[ $# -gt 1 ]]; then
    container="$2"
  fi

  check_service "$service" "$ACTIVE_EXPRESSION" "$ACTIVE_OK" "$container"
}

function check_service() {
  local service=$1
  local expression=$2
  local ok_value=$3
  local container

  if [[ $# -gt 3 && -n "$4" ]]; then
    container="$4"
  else
    container=$(docker compose ps -q "$service")
  fi

  if test "$(docker inspect -f "$expression" "$container")" == "$ok_value"; then
    echo 1
  else
    echo 0
  fi
}

function wait_for_service() {
  local max_attempts=10
  local interval=2
  local service=$1
  local expression=$2
  local ok_value=$3
  local container

  echo "Waiting for $service. Expression=$expression, OkValue=$3, MaxAttempts=$max_attempts, Interval=${interval}s" >&2

  container=$(docker compose ps -q "$service")
  attempts="$max_attempts"

  while true; do
    if [[ "$(check_service "$service" "$expression" "$ok_value" "$container")" -eq 1 ]]; then
      break
    fi

    attempts=$(( attempts - 1 ))

    if [[ "$attempts" -lt 0 ]]; then
      echo "Service did not start successfully: $service" >&2
      exit 1
    fi

    sleep "$interval"
  done
}

cd "$dir"

echo "Local Environment Location: $(pwd)" >&2
echo >&2

case "$1" in
create|start) start_environment;;
status) display_environment_status;;
stop) stop_environment;;
destroy) destroy_environment;;
*)
  {
    echo "Supply one of the following commands: create, start, stop, and destroy."
    echo
    echo "USAGE: $(basename "$0") COMMAND"
    echo
    echo "  create:  Create and start your environment"
    echo
    echo "  start:   The same as \"create\""
    echo
    echo "  status:  Display the environment's status"
    echo
    echo "  stop:    Shutdown your environment but do not destroy any resources"
    echo
    echo "  destroy: Shutdown your environment and destroy all resources"
    echo "           Warning: this will delete all your database's data"
    echo
  } >&2
  exit 1
  ;;
esac
