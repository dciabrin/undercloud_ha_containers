#!/bin/sh

. $(dirname ${BASH_SOURCE[0]})/undercloud-utils.sh

# general config
. $(dirname ${BASH_SOURCE[0]})/config
. $(dirname ${BASH_SOURCE[0]})/vip-config

# assume machine is running on a single NIC for the time being
sed -i 's%\(OS::TripleO::Undercloud::Net::SoftwareConfig:.*\)$%OS::TripleO::Undercloud::Net::SoftwareConfig: ../net-config-noop.yaml%' $HOME/tripleo-heat-templates/environments/undercloud.yaml

# force unique virtual ips for pacemaker haproxy service
LOCAL_IP=${LOCAL_IP:-`/usr/sbin/ip -4 route get 8.8.8.8 | awk {'print $7'} | tr -d '\n'`}
LOCAL_IP_NETWORK=$(ip a | grep "$LOCAL_IP" | awk '{print $2}')

. $(dirname ${BASH_SOURCE[0]})/vip-config
CONTROLLER_VIRTUAL_IP=${CONTROLLER_VIRTUAL_IP:-$(python -c "import netaddr; print netaddr.IPNetwork('$LOCAL_IP_NETWORK')[-2]")}
INTERNAL_API_VIRTUAL_IP=${INTERNAL_API_VIRTUAL_IP:-$(python -c "import netaddr; print netaddr.IPNetwork('$LOCAL_IP_NETWORK')[-3]")}
KEYSTONE_ADMIN_API_VIP=${KEYSTONE_ADMIN_API_VIP:-$(python -c "import netaddr; print netaddr.IPNetwork('$LOCAL_IP_NETWORK')[-4]")}
KEYSTONE_PUBLIC_API_VIP=${KEYSTONE_PUBLIC_API_VIP:-$(python -c "import netaddr; print netaddr.IPNetwork('$LOCAL_IP_NETWORK')[-5]")}
PUBLIC_VIRTUAL_IP=${PUBLIC_VIRTUAL_IP:-$(python -c "import netaddr; print netaddr.IPNetwork('$LOCAL_IP_NETWORK')[-6]")}
REDIS_VIP=${REDIS_VIP:-$(python -c "import netaddr; print netaddr.IPNetwork('$LOCAL_IP_NETWORK')[-7]")}
STORAGE_MGMT_VIRTUAL_IP=${STORAGE_MGMT_VIRTUAL_IP:-$(python -c "import netaddr; print netaddr.IPNetwork('$LOCAL_IP_NETWORK')[-8]")}
STORAGE_VIRTUAL_IP=${STORAGE_VIRTUAL_IP:-$(python -c "import netaddr; print netaddr.IPNetwork('$LOCAL_IP_NETWORK')[-9]")}
MYSQL_VIP=${MYSQL_VIP:-$(python -c "import netaddr; print netaddr.IPNetwork('$LOCAL_IP_NETWORK')[-10]")}
GLANCE_API_VIP=${GLANCE_API_VIP:-$(python -c "import netaddr; print netaddr.IPNetwork('$LOCAL_IP_NETWORK')[-11]")}

VIP_CONFIG=$HOME/tripleo-heat-templates/puppet/all-nodes-config.yaml
sed -i 's%\(controller_virtual_ip:\) {get_param: \[NetVipMap.*%\1 '$CONTROLLER_VIRTUAL_IP'%' $VIP_CONFIG
sed -i 's%\(internal_api_virtual_ip:\) {get_param: \[NetVipMap.*%\1 '$INTERNAL_API_VIRTUAL_IP'%' $VIP_CONFIG
sed -i 's%get_param: \[NetVipMap.*keystone_public_api_network.*%'$KEYSTONE_PUBLIC_API_VIP'%' $VIP_CONFIG
sed -i 's%get_param: \[NetVipMap.*keystone_admin_api_network.*%'$KEYSTONE_ADMIN_API_VIP'%' $VIP_CONFIG
sed -i 's%\(public_virtual_ip:\) {get_param: \[NetVipMap.*}%\1 '$PUBLIC_VIRTUAL_IP'%' $VIP_CONFIG
sed -i 's%\(redis_vip:\) {get_param: RedisVirtualIP}.*%\1 '$REDIS_VIP'%' $VIP_CONFIG
sed -i 's%\(storage_mgmt_virtual_ip:\) {get_param: \[NetVipMap.*%\1 '$STORAGE_MGMT_VIRTUAL_IP'%' $VIP_CONFIG
sed -i 's%\(storage_virtual_ip:\) {get_param: \[NetVipMap.*%\1 '$STORAGE_VIRTUAL_IP'%' $VIP_CONFIG
sed -i 's%\( *\)\(redis_vip:.*\)%\1\2\n\1mysql_vip: '$MYSQL_VIP'%' $VIP_CONFIG
sed -i 's%\( *\)\(redis_vip:.*\)%\1\2\n\1glance_api_vip: '$GLANCE_API_VIP'%' $VIP_CONFIG

# create config files for deploying the HA containers
cat > $THT/environments/ha-docker.yaml <<EOF
resource_registry:
  OS::TripleO::Services::MySQL: ../docker/services/pacemaker/database/mysql.yaml
  OS::TripleO::Services::RabbitMQ: ../docker/services/pacemaker/rabbitmq.yaml
  OS::TripleO::Services::Redis: ../docker/services/pacemaker/database/redis.yaml
  OS::TripleO::Services::HAproxy: ../docker/services/pacemaker/haproxy.yaml
  OS::TripleO::Services::Clustercheck: ../docker/services/pacemaker/clustercheck.yaml
  OS::TripleO::Services::CinderVolume: ../docker/services/pacemaker/cinder-volume.yaml
  OS::TripleO::Services::CinderBackup: ../docker/services/pacemaker/cinder-backup.yaml

parameter_defaults:
  DockerNamespace: 192.168.24.1:8787/tripleoupstream
  DockerNamespaceIsRegistry: true
EOF

cat > $THT/roles_data_undercloud.yaml <<EOF
- name: Undercloud
  CountDefault: 1
  disable_constraints: True
  tags:
    - primary
    - controller
  ServicesDefault:
    - OS::TripleO::Services::TripleoFirewall
    - OS::TripleO::Services::Pacemaker
    - OS::TripleO::Services::RabbitMQ
    - OS::TripleO::Services::Redis
    - OS::TripleO::Services::HAproxy
    - OS::TripleO::Services::MySQL
    - OS::TripleO::Services::MySQLClient
    - OS::TripleO::Services::Clustercheck
    - OS::TripleO::Services::CinderApi
    - OS::TripleO::Services::CinderVolume
    - OS::TripleO::Services::Keystone
    - OS::TripleO::Services::GlanceApi
EOF

sed -i 's%\(keep-running.*\)%keep-running '"${DEPLOY_CMD_CONFIG}"' -e /root/custom.yaml%' $HOME/run.sh

cat > $HOME/cleanup.sh <<EOF
#!/usr/bin/env bash
set -x
pcs cluster destroy
killall epmd
rm -rf /var/lib/mysql
rm -rf /var/lib/rabbitmq
for i in /var/log/puppet /var/lib/config-data /var/lib/heat-config/deployed /etc/puppet/hieradata /var/lib/docker-puppet /var/log/pacemaker/bundles; do
  find \$i/ -type f -or -type l -delete
  rm -rf \$i/*
done
sudo docker ps -qa | xargs sudo docker rm -f
sudo docker volume ls -q | xargs sudo docker volume rm
EOF
