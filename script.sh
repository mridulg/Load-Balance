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