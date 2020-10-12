#!/bin/bash


# the directory containing the script file
dir="$(cd "$(dirname "$0")"; pwd)"
cd "$dir"

log()   { echo -e "\e[30;47m ${1^^} \e[0m ${@:2}"; }        # $1 uppercase background white
info()  { echo -e "\e[48;5;28m ${1^^} \e[0m ${@:2}"; }      # $1 uppercase background green
warn()  { echo -e "\e[48;5;202m ${1^^} \e[0m ${@:2}" >&2; } # $1 uppercase background orange
error() { echo -e "\e[48;5;196m ${1^^} \e[0m ${@:2}" >&2; } # $1 uppercase background red

# log $1 in underline then $@ then a newline
under() {
    local arg=$1
    shift
    echo -e "\033[0;4m${arg}\033[0m ${@}"
    echo
}

usage() {
    under usage 'call the Makefile directly: make dev
      or invoke this file directly: ./make.sh dev'
}

# docker pull, npm install, docker network
setup() {
    # docker pull ...
    log docker pull golang:alpine
    docker pull golang:alpine

    log docker pull node:14.9-slim
    docker pull node:14.9-slim

    cd "$dir/node-consumer"
    npm install

    cd "$dir/node-publisher"
    npm install

    # docker network
    if [[ -z $(docker network ls --format '{{.Name}}' | grep rabbitmq) ]]
    then
        log docker create network rabbitmq
        docker network create rabbitmq
    fi
}

# build the images
build() {
    cd "$dir/node-publisher"
    log build node-publisher
    docker image build \
        --tag node-publisher \
        .

    cd "$dir/go-publisher"
    log build go-publisher
    docker image build \
        --tag go-publisher \
        .

    cd "$dir/node-consumer"
    log build node-consumer
    docker image build \
        --tag node-consumer \
        .
}

# run single rabbitmq
run-rabbitmq-single() {
    [[ -n $(docker ps --format '{{.Names}}' | grep rabbit) ]] \
        && { error error container already exists; return; }

    log run rabbitmq:3-management on http://localhost:8000
    docker run \
        --detach \
        --rm \
        --net rabbitmq \
        --publish 8000:15672 \
        --hostname rabbit \
        --name rabbit \
        rabbitmq:3-management
}

# stop and remove the rabbit container
rm-rabbitmq-single() {
    [[ -z $(docker ps --format '{{.Names}}' | grep rabbit$) ]]  \
        && { warn warn no running container found; return; }
    
    docker container rm --force rabbit
}

# run the node-publisher image
run-node-publisher() {
    [[ -n $(docker ps --format '{{.Names}}' | grep node-publisher) ]] \
        && { error error container already exists; return; }

    log run node-publisher on http://localhost:3000
    cd "$dir/node-publisher"
    docker run \
        --net rabbitmq \
        --env RABBIT_HOST=rabbit \
        --env RABBIT_PORT=5672 \
        --env RABBIT_USERNAME=guest \
        --env RABBIT_PASSWORD=guest \
        --name node-publisher \
        --publish 3000:3000 \
        --volume "$PWD:/app" \
        node-publisher

    # curl -X POST http://localhost:3000/publish/hello
}

# stop and remove the node-publisher container
rm-node-publisher() {
    [[ -z $(docker ps --format '{{.Names}}' | grep node-publisher) ]]  \
        && { warn warn no running container found; return; }
    
    docker container rm --force node-publisher
}

# run the go-publisher image
run-go-publisher() {
    [[ -n $(docker ps --format '{{.Names}}' | grep go-publisher) ]] \
        && { error error container already exists; return; }

    log run go-publisher on http://localhost:4000
    cd "$dir/go-publisher"
    docker run \
        --rm \
        --net rabbitmq \
        --env RABBIT_HOST=rabbit \
        --env RABBIT_PORT=5672 \
        --env RABBIT_USERNAME=guest \
        --env RABBIT_PASSWORD=guest \
        --name go-publisher \
        --publish 4000:4000 \
        go-publisher

    # curl -X POST http://localhost:4000/publish/world
}

# stop and remove the go-publisher container
rm-go-publisher() {
    [[ -z $(docker ps --format '{{.Names}}' | grep go-publisher) ]]  \
        && { warn warn no running container found; return; }
    
    docker container rm --force go-publisher
}

run-node-consumer() {
    [[ -n $(docker ps --format '{{.Names}}' | grep node-consumer) ]] \
        && { error error container already exists; return; }

    log run node-consumer
    cd "$dir/node-consumer"
    docker run -it \
        --rm \
        --net rabbitmq \
        --env RABBIT_HOST=rabbit \
        --env RABBIT_PORT=5672 \
        --env RABBIT_USERNAME=guest \
        --env RABBIT_PASSWORD=guest \
        --name node-consumer \
        node-consumer

    # curl -X POST http://localhost:3000/publish/hey
    # curl -X POST http://localhost:4000/publish/you
}

# stop and remove the node-consumer container
rm-node-consumer() {
    [[ -z $(docker ps --format '{{.Names}}' | grep node-consumer) ]]  \
        && { warn warn no running container found; return; }
    
    docker container rm --force node-consumer
}

create-cluster-item() {
    [[ -n $(docker ps --format '{{.Names}}' | grep $1) ]] \
        && { error error container already exists; return; }

    log run rabbitmq as $1 on http://localhost:$2
    docker run \
        --rm \
        --detach \
        --net rabbitmq \
        --env RABBITMQ_CONFIG_FILE=/config/rabbitmq \
        --env RABBITMQ_ERLANG_COOKIE=the-cookie-id \
        --hostname $1 \
        --name $1 \
        --publish $2:15672 \
        --volume ${PWD}/config/:/config/ \
        rabbitmq:3-management

    until [[ -n $(docker exec $1 cat /var/lib/rabbitmq/.erlang.cookie 2>/dev/null) ]]; do
        echo Waiting cookie ...
        sleep 1
    done

    log enable rabbitmq_federation plugin
    docker exec $1 rabbitmq-plugins enable rabbitmq_federation

    until [[ -n $(docker exec $1 rabbitmqctl cluster_status 2>/dev/null | grep status) ]]; do
        echo Waiting cluster ...
        sleep 5
    done
}

create-cluster() {
    cd "$dir"
    create-cluster-item rabbit 8000
    create-cluster-item mirror-1 8001
    create-cluster-item mirror-2 8002

    log rabbitmqctl set policy
    docker exec rabbit rabbitmqctl set_policy federation \
        '.*' \
        '{ "federation-upstream-set":"all", "ha-sync-mode":"automatic", "ha-mode":"nodes", "ha-params":["rabbit@rabbit", "rabbit@mirror-1", "rabbit@mirror-2"] }' \
        --priority 1 \
        --apply-to queues
}

# run the go-publisher image
run-publish-on-mirror() {
    [[ -n $(docker ps --format '{{.Names}}' | grep go-publisher) ]] \
        && { error error container already exists; return; }

    log run go-publisher on http://localhost:4000
    cd "$dir/go-publisher"
    docker run \
        --rm \
        --net rabbitmq \
        --env RABBIT_HOST=mirror-1 \
        --env RABBIT_PORT=5672 \
        --env RABBIT_USERNAME=guest \
        --env RABBIT_PASSWORD=guest \
        --name go-publisher \
        --publish 4000:4000 \
        go-publisher

    # curl -X POST http://localhost:4000/publish/world
}



# if `$1` is a function, execute it. Otherwise, print usage
# compgen -A 'function' list all declared functions
# https://stackoverflow.com/a/2627461
FUNC=$(compgen -A 'function' | grep $1)
[[ -n $FUNC ]] && { info execute $1; eval $1; } || usage;
exit 0