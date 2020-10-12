.SILENT:

help:
	{ grep --extended-regexp '^[a-zA-Z_-]+:.*#[[:space:]].*$$' $(MAKEFILE_LIST) || true; } \
	| awk 'BEGIN { FS = ":.*#[[:space:]]*" } { printf "\033[1;32m%-25s\033[0m%s\n", $$1, $$2 }'

setup: # docker pull, npm install, docker network
	./make.sh setup

build: # build the images
	./make.sh build

run-rabbitmq-single: # run single rabbitmq
	./make.sh run-rabbitmq-single

rm-rabbitmq-single: # stop and remove the rabbit container
	./make.sh rm-rabbitmq-single

run-node-publisher: # run the node-publisher image
	./make.sh run-node-publisher

rm-node-publisher: # stop and remove the node-publisher container
	./make.sh rm-node-publisher

run-go-publisher: # run the go-publisher image
	./make.sh run-go-publisher

rm-go-publisher: # stop and remove the go-publisher container
	./make.sh rm-go-publisher

run-node-consumer: # run the node-consumer image
	./make.sh run-node-consumer
	
rm-node-consumer: # stop and remove the node-consumer container
	./make.sh rm-node-consumer

create-cluster: # create-cluster
	./make.sh create-cluster

run-publish-on-mirror: # publish on mirror
	./make.sh run-publish-on-mirror
