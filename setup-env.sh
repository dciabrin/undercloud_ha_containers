#!/bin/sh

# dependencies
yum install -y emacs-nox yum-utils ntp fence-agents-all
# pip is in epel
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum install -y python2-pip
pip install git-review netaddr
yum-config-manager --disable epel epel-testing
# builds for new pacemaker
yum-config-manager --add-repo http://people.redhat.com/mbaldess/rpms/container-repo/pacemaker-bundle.repo && yum install -y pacemaker pacemaker-remote pcs libqb resource-agents

# general config
. $(dirname ${BASH_SOURCE[0]})/config

# prepare a local registry and all docker to read from it over http
LOCAL_IFACE=${LOCAL_IFACE:-`/usr/sbin/ip -4 route get 8.8.8.8 | awk {'print $5'} | tr -d '\n'`}
ip a add 192.168.24.1/32 dev $LOCAL_IFACE
export LOCAL_REGISTRY=192.168.24.1:8787

if [ -x ./pre-uc-setup.sh ]; then
    ./pre-uc-setup.sh
else
    yum install -y centos-release-openstack-ocata
fi

# install dprince's containerized undercloud environment
# configure it based on LOCAL_IFACE and LOCAL_REGISTRY
git clone https://github.com/dprince/undercloud_containers $HOME/undercloud_containers
(cd $HOME/undercloud_containers && ./doit.sh)
# assume machine is running on a single NIC for the time being
sed -i 's%\(OS::TripleO::Undercloud::Net::SoftwareConfig:.*\)$%OS::TripleO::Undercloud::Net::SoftwareConfig: ../net-config-noop.yaml%' $HOME/tripleo-heat-templates/environments/undercloud.yaml

if [ -x ./post-uc-setup.sh ]; then
    ./post-uc-setup.sh
else
    yum-config-manager --disable epel epel-testing delorean delorean-pike-testing
fi

yum install docker docker-registry
echo "INSECURE_REGISTRY='--insecure-registry ${LOCAL_REGISTRY}'" "${DOCKER_REGISTRY_EXTRA_CONFIG}" >> /etc/sysconfig/docker
sed -i "s/addr:.*/addr: ${LOCAL_REGISTRY}/" /etc/docker-distribution/registry/config.yml
systemctl enable docker docker-distribution
systemctl stop docker docker-distribution
systemctl start docker docker-distribution

# re-clone tripleo-heat-templates and cherry pick a few ongoing reviews (cinder)
rm -rf $HOME/tripleo-heat-templates
git clone https://github.com/openstack/tripleo-heat-templates $HOME/tripleo-heat-templates
pushd $HOME/tripleo-heat-templates
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/38/462538/4 && git cherry-pick FETCH_HEAD
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/89/465989/3 && git cherry-pick FETCH_HEAD
git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/11/457011/14 && git cherry-pick FETCH_HEAD
popd

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
popd

# clone the HA reviews and set hard link in tripleo-heat-templates and
# puppet-tripleo directories
. $(dirname ${BASH_SOURCE[0]})/generate-configs.sh

echo -e "\nSetup done. Run build-kolla-images.sh before deploying your containers\n"
