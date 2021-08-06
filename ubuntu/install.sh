#!/bin/bash

# https://www.linuxfordevices.com/tutorials/ubuntu/install-openstack-on-ubuntu

sudo apt-get install \
  --yes \
  openssh-server \
  openssh-client

sudo apt-get update

sudo apt-get upgrade --yes

sudo apt-get install iptables
sudo apt-get install arptables
sudo apt-get install ebtables

sudo update-alternatives --set iptables /usr/sbin/iptables-legacy || true
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy || true
sudo update-alternatives --set arptables /usr/sbin/arptables-legacy || true
sudo update-alternatives --set ebtables /usr/sbin/ebtables-legacy || true

sudo apt autoremove --yes

sudo useradd -s /bin/bash -d /opt/stack -m stack

echo "stack ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/stack

sudo su - stack

git clone \
  --single-branch \
  --branch "stable/wallaby" https://opendev.org/openstack/devstack

cd devstack

cp ./samples/local.conf local.conf

vim local.conf

sed -i '/ADMIN_PASSWORD=/ s/ADMIN_PASSWORD.*/ADMIN_PASSWORD=nomoresecret/g' local.conf
sed -i '/DATABASE_PASSWORD=/ s/DATABASE_PASSWORD.*/DATABASE_PASSWORD=stackdb/g' local.conf
sed -i '/RABBIT_PASSWORD=/ s/RABBIT_PASSWORD.*/RABBIT_PASSWORD=stackqueue/g' local.conf

sed -i '/#HOST_IP=w.x.y.z/c\HOST_IP=192.168.68.114' local.conf

./stack.sh
