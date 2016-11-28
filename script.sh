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
  slave

# We will set the private IP for this as SLAVE1_IP.
export SLAVE_IP=$(docker-machine ssh slave 'ifconfig eth0 | grep "inet addr:" | cut -d: -f2 | cut -d" " -f1')


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
  -h ${SLAVE_IP} \
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
# See the `docker-compose.yml` file 

# The first service is web and it contains the image hanzel/tutum-nodejs-redis, which is the node.js application.
# We are pulishing the port 4000 inside the container. It will be mapped to some port of the host. We need to setup some environment variables:

# APP_PORT: Port to run the Node.js application.
# REDIS_IP: The IP of the redis instance.
# REDIS_PORT: The PORT of the redis instance.
# The second service is the official redis image. For persistant data storage, we are creating a data volumes named redis-data.
# This volume is of the type local, so the data is stored in the local host system.

# The services in the same network are linked. Here, both these services are in the back-tier network which is of the type overlay.
# The overlay network allow multi-host networking, this allows the service to be linked even if the these are in different hosts.
docker-compose up -d

# Check details about the running services with the command docker-compose ps
docker-compose ps


# 
# LOAD BALANCER
# 

# We have a single instance of the app running.
# We need to now implement a load balancer that can distribute the traffic across all the instances of this service.
# As we increase and decrease the instances of the service, we need to automatically update the load balancer.

# We have new service name lb. It is build using Dockerfile in the current directory. The port 80 of the container is mapped to port 80 of the host. We need to set up three environment variables:

# constraint:node: The name of the node where this service should run. We want the load balancing to always run on the master node.
# APP_NAME: The image name of the service you need to load balance. Here, it is tutum-nodejs-redis. You can load balance any service by providing its name here.
# CONSUL_URL: The url of consul. We are using the KV_IP environment variable for this.
# We have a new overlay network named front-tier. This connects lb and web services. Note that, the load balancer doesn’t need to connect to redis, so these are put in two different networks. The web services is connected to both these networks.

# Instead of building a new image, you may use the image hanzel/load-balancing-swarm. Just replace the line build: . with image: hanzel/load-balancing-swarm.

# Now we need to stop and remove the running services and start the new services.


docker-compose stop 
docker-compose rm -f
docker-compose up -d
# We will scale this to three with the following command.
docker-compose scale web=3




# You can stop the services and remove the hosts using the following commands.
# docker-compose down
# docker-machine stop consul master slave
# docker-machine rm consul master slave
