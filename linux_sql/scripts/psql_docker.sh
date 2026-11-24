#!/bin/sh

# Capture command-line arguments
cmd=$1
db_username=$2
db_password=$3

# Ensure Docker is running
if ! sudo systemctl is-active --quiet docker; then
    sudo systemctl start docker || exit 1
fi

# Check whether the PostgreSQL container exists
docker container inspect jrvs-psql >/dev/null 2>&1
container_status=$?

# Handle create, start and stop commands
case "$cmd" in
    create)
        # Check whether the required arguments are provided
        if [ "$#" -ne 3 ] || [ -z "$db_username" ] || [ -z "$db_password" ]; then
            echo "Error: Create requires username and password"
            exit 1
        fi

        # Prevent duplicate containers
        if [ "$container_status" -eq 0 ]; then
            echo "Error: Container already exists"
            exit 1
        fi

        # Create persistent storage
        docker volume create pgdata || exit 1

        # Create and start PostgreSQL
        docker run --name jrvs-psql \
            -e POSTGRES_USER="$db_username" \
            -e POSTGRES_PASSWORD="$db_password" \
            -d \
            -v pgdata:/var/lib/postgresql/data \
            -p 127.0.0.1:5432:5432 \
            postgres:17-alpine

        exit $?
        ;;

    start|stop)
        # Check whether the container exists
        if [ "$container_status" -ne 0 ]; then
            echo "Error: Container does not exist"
            exit 1
        fi

        # Start or stop the existing container
        docker container "$cmd" jrvs-psql
        exit $?
        ;;

    *)
        echo "Error: Invalid command"
        echo "Usage: $0 create username password | start | stop"
        exit 1
        ;;
esac

