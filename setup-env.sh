#!/bin/sh

# dependencies
yum install -y git python2-pip emacs-nox yum-utils ntp fence-agents-all
pip install git-review
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
. $(dirname $0)/clone-reviews.sh

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
