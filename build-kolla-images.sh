#!/bin/sh

. $(dirname ${BASH_SOURCE[0]})/config

pushd $HOME/kolla

cat > kolla-build.conf <<EOF
[DEFAULT]
base=centos
type=binary
rpm_setup_config = http://trunk.rdoproject.org/centos7/current/delorean.repo,http://trunk.rdoproject.org/centos7/delorean-deps.repo
EOF

TAG=${DOCKER_IMAGE_TAG:-latest}
KOLLA_TAG=5.0.0

PULL_IMGS="glance-api keystone"
for i in $PULL_IMGS; do sudo docker pull tripleoupstream/centos-binary-$i:$TAG; done
for i in $PULL_IMGS; do sudo docker tag tripleoupstream/centos-binary-$i:$TAG 192.168.24.1:8787/tripleoupstream/centos-binary-$i:$TAG; done

BUILD_IMGS="mariadb rabbitmq haproxy redis cinder-base cinder-api cinder-backup cinder-scheduler manila-base manila-api manila-data manila-scheduler manila-share"
time sudo kolla-build  --config-file=kolla-build.conf --template-override tripleo_kolla_template_overrides.j2 --namespace tripleoupstream --registry 192.168.24.1:8787 $BUILD_IMGS
for i in $BUILD_IMGS; do sudo docker tag 192.168.24.1:8787/tripleoupstream/centos-binary-$i:$KOLLA_TAG 192.168.24.1:8787/tripleoupstream/centos-binary-$i:$TAG; done

DEPLOY_IMGS="$PULL_IMGS $BUILD_IMGS"
for i in $DEPLOY_IMGS; do sudo docker push 192.168.24.1:8787/tripleoupstream/centos-binary-$i:$TAG; done
popd
