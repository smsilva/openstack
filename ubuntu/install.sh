#!/bin/bash

# https://stackoverflow.com/questions/59109557/how-to-expose-the-devstack-floating-ip-to-the-external-world

# https://www.linuxfordevices.com/tutorials/ubuntu/install-openstack-on-ubuntu

# https://docs.openstack.org/devstack/latest/guides/single-machine.html#prerequisites-linux-network

# OpenStack (victoria): Bringing up DevStack on Ubuntu 20.04
# https://www.youtube.com/watch?v=1uyQUU3gXZo

# How to install Openstack all in one in Ubuntu 20.10
# https://www.youtube.com/watch?v=sJ92sWgEAd8

# https://docs.openstack.org/devstack/latest/networking.html

echo "${USER} ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/${USER}

sudo timedatectl set-timezone America/Sao_Paulo

sudo apt-get update

sudo apt-get upgrade --yes

sudo apt-get install --yes \
  arptables \
  bridge-utils \
  ebtables \
  git \
  iptables \
  net-tools \
  ntp \
  open-vm-tools \
  open-vm-tools-desktop \
  openssh-client \
  openssh-server \
  python3-pip

/usr/bin/python3.8 -m pip install --upgrade pip

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

sudo sed -i '/#DNS=/ s/#DNS=.*/DNS=192.168.68.1 8.8.8.8/g' /etc/systemd/resolved.conf
sudo systemctl restart systemd-resolved

sudo rm -rf /etc/netplan/00-installer-config.yaml

cat <<EOF | sudo tee /etc/netplan/01-netcfg.yaml
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: no
      addresses:
        - 192.168.68.132/24
      gateway4: 192.168.68.1
      nameservers:
          search: [home]
          addresses: [192.168.68.1,8.8.8.8,1.1.1.1]
EOF

sudo netplan apply

echo 1 | sudo tee /proc/sys/net/ipv4/conf/enp0s3/proxy_arp
sudo iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE

sudo rm -rf /usr/lib/python3/dist-packages/yaml
sudo rm -rf /usr/lib/python3/dist-packages/PyYAML-*
sudo rm -rf /usr/lib/python3/dist-packages/simplejson*

cp ./samples/local.conf local.conf

sed -i '/ADMIN_PASSWORD=/ s/ADMIN_PASSWORD.*/ADMIN_PASSWORD=stack/g' local.conf
sed -i '/DATABASE_PASSWORD=/ s/DATABASE_PASSWORD.*/DATABASE_PASSWORD=stackdb/g' local.conf
sed -i '/RABBIT_PASSWORD=/ s/RABBIT_PASSWORD.*/RABBIT_PASSWORD=stackqueue/g' local.conf

cat <<EOF | tee -a local.conf
IP_VERSION=4
HOST_IP=192.168.68.132
FLOATING_RANGE="192.168.68.224/27"
Q_FLOATING_ALLOCATION_POOL=start=192.168.68.226,end=192.168.68.254
EOF

./stack.sh

echo "alias os=openstack" >> openrc

. openrc
