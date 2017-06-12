# Containerized HA undercloud

This repo contains a series of script for setting up a minimal
containerized tripleo undercloud configured with HA settings (pacemaker).

It is based on
[undercloud_containers](https://github.com/dprince/undercloud_containers)
and prepare the setup for ongoing development on HA and containers.

## Example setup

Create a base image for the VM

    $ virt-builder centos-7.3 --size 150G --root-password password:centos --hostname centos

Install the VM (wait a bit and CTRL-C virt-install to return to shell)

    $ virt-install --name undercloud --memory 32768 --vcpu 4 --network bridge=virbr0 --disk centos-7.3.img --import

Look for the IP that has been assigned to the newly created VM

    $ sudo virsh net-dhcp-leases default
     Expiry Time          MAC address        Protocol  IP address                Hostname        Client ID or DUID
    -------------------------------------------------------------------------------------------------------------------
     2017-06-12 17:01:58  52:54:00:48:39:84  ipv4      192.168.122.26/24         centos          -

Log into the machine

    $ ssh root@192.168.122.26
    Warning: Permanently added '192.168.122.26' (ECDSA) to the list of known hosts.
    root@192.168.122.26's password: 
    [root@centos ~]# 

Clone the ha undercloud helpers

    # yum install -y git
    # git clone https://github.com/dciabrin/undercloud_ha_containers

Prepare the undercloud helpers. Some config settings (e.g. VIP) can be customized if needed.

    # ./undercloud_ha_containers/setup-env.sh
    ...
    Setup done. Run build-kolla-images.sh before deploying your containers

Pull Kolla images for a few Openstack services and rebuild the images for the core HA services

    # ./undercloud_ha_containers/build-kolla-images.sh

Deploy a minimal containerized HA undercloud. 
The deploy command line fails due to the deploy not enabling all
openstack services, but the ha cluster is functional.

    # $HOME/run.sh
    # crm_mon -1

Further cleanup and redeploy can be done with:

    # $HOME/cleanup.sh
    # $HOME/run.sh

