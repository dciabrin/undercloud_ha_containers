#!/bin/sh

. $(dirname ${BASH_SOURCE[0]})/undercloud-utils.sh

mkdir $HOME/gerrit
pushd $HOME/gerrit
co_repo tripleo-heat-templates rabbitmq-tht 452889
co_repo tripleo-heat-templates mysql-tht 455348
co_repo tripleo-heat-templates clustercheck-tht 457800
co_repo tripleo-heat-templates haproxy-tht 459597
co_repo tripleo-heat-templates redis-tht 464958
co_repo tripleo-heat-templates cinder-volume-tht 467752
for i in rabbitmq mysql clustercheck haproxy redis cinder-volume; do (cd $i-tht && link_repo $THT); done

co_repo puppet-tripleo rabbitmq-pp 455189
co_repo puppet-tripleo mysql-pp 455345
co_repo puppet-tripleo clustercheck-pp 457797
co_repo puppet-tripleo haproxy-pp 458832
co_repo puppet-tripleo redis-pp 464951
co_repo puppet-tripleo cinder-volume-pp 467749
for i in rabbitmq mysql clustercheck haproxy redis cinder-volume; do (cd $i-pp && link_repo $PP); done

co_repo puppet-pacemaker puppet-pacemaker 463170
(cd puppet-pacemaker && link_repo /etc/puppet/modules/pacemaker)

# MERGED
# co_repo tripleo-common tripleo-common 456174
popd
