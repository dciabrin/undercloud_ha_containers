#!/bin/sh

# dependencies
yum install -y emacs-nox yum-utils ntp fence-agents-all git
# pip is in epel
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum install -y python2-pip
pip install git-review netaddr
yum-config-manager --disable epel epel-testing
# undercloud_containers is what we base our setup upon
git clone https://github.com/dprince/undercloud_containers $HOME/undercloud_containers

# general config
. $(dirname ${BASH_SOURCE[0]})/config

# prepare a local registry and all docker to read from it over http
LOCAL_IFACE=${LOCAL_IFACE:-`/usr/sbin/ip -4 route get 8.8.8.8 | awk {'print $5'} | tr -d '\n'`}
ip a add 192.168.24.1/32 dev $LOCAL_IFACE
export LOCAL_REGISTRY=192.168.24.1:8787

if [ -x $(dirname ${BASH_SOURCE[0]})/pre-uc-setup.sh ]; then
    $(dirname ${BASH_SOURCE[0]})/pre-uc-setup.sh
else
    # builds for new pacemaker
    yum-config-manager --add-repo http://people.redhat.com/mbaldess/rpms/container-repo/pacemaker-bundle.repo && yum install -y pacemaker pacemaker-remote pcs libqb resource-agents
    yum install -y centos-release-openstack-ocata
fi

# install dprince's containerized undercloud environment
# configure it based on LOCAL_IFACE and LOCAL_REGISTRY
rm -rf $HOME/tripleo-heat-templates
(cd $HOME/undercloud_containers && ./doit.sh)

if [ -x $(dirname ${BASH_SOURCE[0]})/post-uc-setup.sh ]; then
    $(dirname ${BASH_SOURCE[0]})/post-uc-setup.sh
else
    yum-config-manager --disable epel epel-testing delorean delorean-pike-testing
fi

# autorize pcs on the host
echo 'hacluster' | passwd hacluster --stdin
pcs cluster auth $HOSTNAME --force -u hacluster -p hacluster

yum install -y docker docker-registry
if ! grep -q '^INSECURE_REGISTRY' /etc/sysconfig/docker; then
    echo "INSECURE_REGISTRY=\"--insecure-registry ${LOCAL_REGISTRY} ${DOCKER_REGISTRY_EXTRA_CONFIG}\"" >> /etc/sysconfig/docker
fi
if ! grep -q '^proxy:' /etc/docker-distribution/registry/config.yml; then
    echo -e "proxy:\n    remoteurl: https://registry-1.docker.io" >> /etc/docker-distribution/registry/config.yml
    sed -i "s/addr:.*/addr: ${LOCAL_REGISTRY}/" /etc/docker-distribution/registry/config.yml
fi
systemctl enable docker docker-distribution
systemctl stop docker docker-distribution
systemctl start docker docker-distribution

# clone the HA reviews and set hard link in tripleo-heat-templates and
# puppet-tripleo directories
. $(dirname ${BASH_SOURCE[0]})/clone-reviews.sh

# setup kolla build environment
rm -rf $HOME/kolla
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

echo -e "\nSetup done. Adapt $HOME/tripleo-heat-templates/roles_data_undercloud.yaml and type $HOME/run.sh to deploy your containers\n"
