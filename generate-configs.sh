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
MYSQL_VIP=${INTERNAL_API_VIRTUAL_IP}

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

# todo: find the proper network setup to override this setting cleanly
ENDPOINT_MAP_CONFIG=$HOME/tripleo-heat-templates/network/endpoints/endpoint_map.yaml
sed -i 's/\(MysqlInternal.*mysql.*host\):.*/\1: '"'${MYSQL_VIP}'"'}/' $ENDPOINT_MAP_CONFIG

NET_IP_MAP_CONFIG=$HOME/tripleo-heat-templates/network/ports/net_ip_map.yaml
# sed -i 's%\( *\)\(internal_api\): .*%\1\2: '$INTERNAL_API_VIRTUAL_IP'%' $NET_IP_MAP_CONFIG
# sed -i 's%\( *\)\(internal_api_uri\): .*%\1\2: '$INTERNAL_API_VIRTUAL_IP'%' $NET_IP_MAP_CONFIG

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
    # - OS::TripleO::Services::CinderVolume
    # - OS::TripleO::Services::CinderBackup
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
for i in /var/log/puppet /var/lib/config-data /var/lib/heat-config/deployed /var/lib/heat-config/heat-config-ansible /var/lib/heat-config/heat-config-script /var/lib/tripleo-config /var/lib/os-collect-config /etc/puppet/hieradata /var/lib/docker-puppet /var/log/pacemaker/bundles; do
  find \$i/ -type f -or -type l -delete
  rm -rf \$i/*
done
sudo docker ps -qa | xargs sudo docker rm -f
sudo docker volume ls -q | xargs sudo docker volume rm
# avoid side effect caused by bad config in roles_data_undercloud
rm -rf /etc/corosync/corosync.d
pcs cluster destroy --force
# clean tripleo firewall, restart docker to reset its firwall rules
iptables -F INPUT
iptables -F FORWARD
sudo systemctl restart docker
EOF

cat >> $HOME/custom.yaml <<EOF
  DockerNamespace: ${DOCKER_NAMESPACE}
  DockerNamespaceIsRegistry: true
EOF
