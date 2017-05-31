#!/bin/sh

# dependencies
yum install -y git python2-pip emacs-nox yum-utils ntp fence-agents-all
pip install git-review netaddr
yum install -y centos-release-openstack-ocata
yum-config-manager --add-repo http://people.redhat.com/mbaldess/rpms/container-repo/pacemaker-bundle.repo && yum install -y pacemaker pacemaker-remote pcs libqb resource-agents

# install dprince's containerized undercloud environment
LOCAL_IFACE=${LOCAL_IFACE:-`/usr/sbin/ip -4 route get 8.8.8.8 | awk {'print $5'} | tr -d '\n'`}
ip a add 192.168.24.1/32 dev $LOCAL_IFACE
export LOCAL_REGISTRY=192.168.24.1:8787
git clone https://github.com/dprince/undercloud_containers $HOME/undercloud_containers
(cd $HOME/undercloud_containers && ./doit.sh)
# assume machine is running on a single NIC for the time being
sed -i 's%\(OS::TripleO::Undercloud::Net::SoftwareConfig:.*\)$%OS::TripleO::Undercloud::Net::SoftwareConfig: ../net-config-noop.yaml%' $HOME/tripleo-heat-templates/environments/undercloud.yaml

# clone the HA reviews and set hard link in tripleo-heat-templates and
# puppet-tripleo directories
. $(dirname ${BASH_SOURCE[0]})/clone-reviews.sh

# setup kolla build environment
mkdir $HOME/kolla
git clone https://github.com/openstack/kolla $HOME/kolla
pushd $HOME/kolla
ln -s $HOME/gerrit/tripleo-common/container-images/tripleo_kolla_template_overrides.j2 .
sudo pip install -r requirements.txt
sudo python setup.py install
cat > kolla-build.conf <<EOF
[DEFAULT]
base=centos
type=binary
rpm_setup_config = http://trunk.rdoproject.org/centos7/current/delorean.repo,http://trunk.rdoproject.org/centos7/delorean-deps.repo
EOF
popd

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
  OS::TripleO::Services::Docker: ../puppet/services/docker.yaml
  OS::TripleO::Compute::NodeUserData: ../docker/firstboot/setup_docker_host.yaml
  OS::TripleO::Services::MySQL: ../docker/services/pacemaker/database/mysql.yaml
  OS::TripleO::Services::RabbitMQ: ../docker/services/pacemaker/rabbitmq.yaml
  OS::TripleO::Services::Redis: ../docker/services/pacemaker/database/redis.yaml
  OS::TripleO::Services::HAProxy: ../docker/services/pacemaker/haproxy.yaml
  OS::TripleO::Services::Clustercheck: ../docker/services/pacemaker/clustercheck.yaml
  OS::TripleO::Services::CinderVolume: ../docker/services/pacemaker/cinder-volume.yaml

  OS::TripleO::PostDeploySteps: ../docker/post.yaml
  OS::TripleO::PostUpgradeSteps: ../docker/post-upgrade.yaml
  OS::TripleO::Services: ../docker/services/services.yaml

parameter_defaults:
  DockerNamespace: 192.168.24.1:8787/tripleoupstream
  DockerNamespaceIsRegistry: true
EOF

cat > $THT/environments/roles_data_undercloud.yaml <<EOF
- name: Undercloud
  CountDefault: 1
  disable_constraints: True
  tags:
    - primary
    - controller
  ServicesDefault:
    - OS::TripleO::Services::Pacemaker
    - OS::TripleO::Services::RabbitMQ
    - OS::TripleO::Services::Redis
    - OS::TripleO::Services::MySQL
    - OS::TripleO::Services::Clustercheck
    - OS::TripleO::Services::HAProxy
    - OS::TripleO::Services::CinderVolume
EOF

sed -i 's%\(keep-running.*\)%keep-running -e /root/tripleo-heat-templates/environments/puppet-pacemaker.yaml -e /root/tripleo-heat-templates/environments/ha-docker.yaml -e /root/custom.yaml%' $HOME/run.sh

cat > $HOME/cleanup.sh <<EOF
#!/usr/bin/env bash
pcs cluster destroy
set -x
rm -rf /var/lib/mysql
rm -rf /var/log/puppet
sudo docker ps -qa | xargs sudo docker rm -f
sudo docker volume ls -q | xargs sudo docker volume rm
EOF

echo -e "\nSetup done. Run build-kolla-images.sh before deploying your containers\n"
