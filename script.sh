# 
# We will be creating a host for running Consul alone. It will not be a part of the swarm. So we can create a host named consul first.
# 
docker-machine create \
  -d vmwarefusion \
  consul


# To see how to connect your Docker Client to the Docker Engine running on this virtual machine, run: docker-machine env consul
docker-machine env consul

# Run this command to configure your shell: 
eval $(docker-machine env consul)

# We will store the private IP of this host as KV_IP environment variable with the following command.
export KV_IP=$(docker-machine ssh consul 'ifconfig eth0 | grep "inet addr:" | cut -d: -f2 | cut -d" " -f1')

# Print it just for the sake of it
echo $KV_IP

# We need to connect out docker client to this host and then run progrium/consul image there.
# This command will pull and deploy the image in consul host.
docker run -d \
  -p ${KV_IP}:8500:8500 \
  -h consul \
  --restart always \
  gliderlabs/consul-server -bootstrap


# THE SWARM 
# A Docker swarm need a master node and an arbitrary number of ordinary nodes. The swarm master is named master and we will create this now.
docker-machine create \
  -d vmwarefusion \
  --swarm \
  --swarm-master \
  --swarm-discovery="consul://${KV_IP}:8500" \
  --engine-opt="cluster-store=consul://${KV_IP}:8500" \
  --engine-opt="cluster-advertise=eth0:2376" \
  master

# We will set the private IP for this host as MASTER_IP.
export MASTER_IP=$(docker-machine ssh master 'ifconfig eth0 | grep "inet addr:" | cut -d: -f2 | cut -d" " -f1')

# We can now create any number of nodes in this swarm. For this example, we will have only one other node in the swarm and it is named slave.
# We will create this host and set its private IP as SLAVE_IP with the following commands.
docker-machine create \
  -d vmwarefusion \
  --swarm \
  --swarm-discovery="consul://${KV_IP}:8500" \
  --engine-opt="cluster-store=consul://${KV_IP}:8500" \
  --engine-opt="cluster-advertise=eth0:2376" \
  slave1

# We will set the private IP for this as SLAVE1_IP.
export SLAVE1_IP=$(docker-machine ssh slave1 'ifconfig eth0 | grep "inet addr:" | cut -d: -f2 | cut -d" " -f1')


# You can create more nodes in the swarm by repeating these commands by just changing the hostname.
# We also need to have a registrator service running in each of these hosts to keep track of all services running in each host.
# The version 6 of gliderlabs/registrator image is used for this.
# We need to connect our client to each of these hosts and run the registrator image.

eval $(docker-machine env master)

docker run -d \
  --name=registrator \
  -h ${MASTER_IP} \
  --volume=/var/run/docker.sock:/tmp/docker.sock \
  gliderlabs/registrator:v6 \
  consul://${KV_IP}:8500

eval $(docker-machine env slave)

docker run -d \
  --name=registrator \
  -h ${SLAVE1_IP} \
  --volume=/var/run/docker.sock:/tmp/docker.sock \
  gliderlabs/registrator:v6 \
  consul://${KV_IP}:8500


# We can see all the hosts created with docker-machine with the command docker-machine ls.
docker-machine ls


# We can now connect the docker client to the swarm.
# For this, we use -swarm parameter with the swarm master.
eval $(docker-machine env -swarm master)

# 
# DOCKER COMPOSE
# 






