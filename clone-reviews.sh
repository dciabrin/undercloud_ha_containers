#!/bin/sh

# Note: all the commented out lines are reviews that have already merged

. $(dirname ${BASH_SOURCE[0]})/undercloud-utils.sh

mkdir $HOME/gerrit
pushd $HOME/gerrit
# co_repo tripleo-heat-templates rabbitmq-tht # merged: 452889
# co_repo tripleo-heat-templates mysql-tht # merged: 455348
# co_repo tripleo-heat-templates clustercheck-tht # merged: 457800
co_repo tripleo-heat-templates haproxy-tht 474943 # merged: 473473 459597
# co_repo tripleo-heat-templates mysql-client-tht # merged: 466531
co_repo tripleo-heat-templates use-mysql-client-tht 469372 #
# co_repo tripleo-heat-templates redis-tht # merged: 464958
# co_repo tripleo-heat-templates cinder-volume-tht # merged: 467752
# co_repo tripleo-heat-templates cinder-backup-tht # merged: 470403
# for i in rabbitmq mysql clustercheck haproxy redis cinder-volume cinder-backup; do (cd $i-tht && link_repo $THT); done
for i in haproxy use-mysql-client; do (cd $i-tht && link_repo $THT); done

# co_repo puppet-tripleo rabbitmq-pp # merged: 455189
# co_repo puppet-tripleo mysql-pp # merged: 455345
# co_repo puppet-tripleo clustercheck-pp # merged: 457797
co_repo puppet-tripleo haproxy-pp 474947 # merged: 458832
# co_repo puppet-tripleo redis-pp # merged: 464951
# co_repo puppet-tripleo cinder-volume-pp # merged: 467749
# co_repo puppet-tripleo cinder-backup-pp # merged: 470398
# location rules 472184, all reviews
# for i in rabbitmq mysql clustercheck haproxy redis cinder-volume cinder-backup; do (cd $i-pp && link_repo $PP); done
# for i in cinder-volume cinder-backup; do (cd $i-pp && link_repo $PP); done
for i in haproxy; do (cd $i-pp && link_repo $PP); done

(cd /etc/puppet/modules && rm -rf pacemaker && co_repo puppet-pacemaker pacemaker)
# co_repo puppet-pacemaker puppet-pacemaker # merged: 476486 472781 463170
# (cd puppet-pacemaker && link_repo /etc/puppet/modules/pacemaker)

# MERGED
# co_repo tripleo-common tripleo-common 456174
co_repo tripleo-common tripleo-common
popd
