#!/bin/sh

pushd $HOME/kolla

BUILD_IMGS="mariadb rabbitmq haproxy redis keystone cinder glance"
DEPLOY_IMGS="mariadb rabbitmq haproxy redis keystone cinder-volume cinder-api glance-api"

time sudo kolla-build --config-file=kolla-build.conf --template-override tripleo_kolla_template_overrides.j2 --namespace tripleoupstream --registry 192.168.24.1:8787 $BUILD_IMGS
for i in $DEPLOY_IMGS; do sudo docker tag 192.168.24.1:8787/tripleoupstream/centos-binary-$i:4.0.0 192.168.24.1:8787/tripleoupstream/centos-binary-$i:latest; done
for i in $DEPLOY_IMGS; do sudo docker push 192.168.24.1:8787/tripleoupstream/centos-binary-$i:latest; done

popd
