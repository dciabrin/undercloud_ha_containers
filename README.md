# Containerized HA undercloud

This repo contains a series of scripts for setting up a minimal
containerized tripleo undercloud configured with HA settings (pacemaker).

It is based on
[undercloud_containers](https://github.com/dprince/undercloud_containers)
and prepares the setup for ongoing developments around containerized HA.

## Example setup

Create a base image for the VM

    $ virt-builder centos-7.3 --size 150G --root-password password:centos --hostname centos

Install the VM

    $ virt-install --name undercloud --memory 32768 --vcpu 4 --network bridge=virbr0 --disk centos-7.3.img --import --wait 1

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
    Setup done. Adapt /root/tripleo-heat-templates/roles_data_undercloud.yaml and type /root/run.sh to deploy your containers

If you want to manually rebuild the kolla images for core HA services

    # ./undercloud_ha_containers/build-kolla-images.sh

Deploy a minimal containerized HA undercloud. You will get a STACK_CREATE complete, which indicates a succesful deployment.

    # $HOME/run.sh
    [...]
    2017-07-12 14:18:45Z [undercloud]: CREATE_COMPLETE  Stack CREATE completed successfully
    
    Deploy Successful.
    [...]
    # crm_mon -1

Further cleanup and redeploy can be done with:

    # $HOME/cleanup.sh
    # $HOME/run.sh
