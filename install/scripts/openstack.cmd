openstack_project=devel
openstack_internal_network=devel_net
openstack_internal_subnet=devel_subnet
openstack_user_admin=cloud-admin

. keystonerc_admin

openstack image create \
--public \
--disk-format qcow2 \
--min-disk 15 \
--min-ram 512 \
--file "/osp/images/centos7.qcow2" \
centos7

openstack network create \
--share \
--external \
--provider-network-type flat \
--provider-physical-network physnet1 \
public_network

openstack subnet create \
--dhcp \
--subnet-range 192.168.1.0/24 \
--allocation-pool start=192.168.1.20,end=192.168.1.90 \
--dns-nameserver 192.168.1.1 \
--network public_network \
public_subnet
		  
openstack project create $openstack_project

openstack user create \
--project $openstack_project \
--password openstack \
cloud-admin

openstack user create \
--project $openstack_project \
--password openstack \
cloud-dev

openstack role add \
--project $openstack_project \
--user cloud-dev \
_member_

openstack role add \
--project $openstack_project \
--user cloud-admin \
admin

openstack role add \
--project $openstack_project \
--user cloud-admin \
heat_stack_owner

openstack role assignment list \
--project $openstack_project \
--names

cat <<EOF > keystonerc_$openstack_user_admin
unset OS_SERVICE_TOKEN
export OS_USERNAME=$openstack_user_admin
export OS_PASSWORD='openstack'
export OS_AUTH_URL=http://192.168.1.101:5000/v3
export OS_PROJECT_NAME=$openstack_project
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_IDENTITY_API_VERSION=3
export PS1='[\u@\h ($openstack_user_admin) \W]\$ '
EOF

. keystonerc_$openstack_user_admin

openstack network create \
--internal \
--provider-network-type vxlan \
$openstack_internal_network

openstack subnet create \
--subnet-range 10.0.0.0/24 \
--allocation-pool start=10.0.0.20,end=10.0.0.90 \
--gateway 10.0.0.1 \
--dns-nameserver 192.168.1.1 \
--network $openstack_internal_network \
$openstack_internal_subnet

openstack router create \
--project $openstack_project \
devel_router1

openstack router add subnet \
devel_router1 \
$openstack_internal_subnet

openstack keypair create \
--private-key .ssh/id_rsa \
director

openstack keypair show director \
--public-key > .ssh/id_rsa.pub

chmod 600 .ssh/id_rsa

neutron router-gateway-set devel_router1 public_network

openstack_public_network_id=$(openstack network show public_network -c id -f value)

openstack_internal_network_id=$(openstack network show $openstack_internal_network -c id -f value)

openstack_internal_subnet_id=$(openstack subnet show $openstack_internal_subnet -c id -f value)

openstack port create \
--disable-port-security \
--no-security-group \
--fixed-ip subnet=$openstack_internal_subnet_id,ip-address=10.0.0.51 \
--network $openstack_internal_network_id \
port-51

openstack floating ip create \
--project $openstack_project \
--port port-51 \
--floating-ip-address 192.168.1.51 \
$openstack_public_network_id

cat <<EOF > /osp/cloud-init/ftp-51.yml
#cloud-config
cloud_config_modules:
- disk_setup
- mounts

hostname: ftp-51
fqdn: ftp-51.example.com

disk_setup:
  /dev/vdb:
    table_type: 'mbr'
    layout: true
    overwrite: false

fs_setup:
  - label: 'ftp_data'
    filesystem: 'ext4'
    device: '/dev/vdb1'
    partition: 'auto'

runcmd:
- mkdir -p /mnt/ftp-data

mounts:
- [ /dev/vdb1, /mnt/ftp-data, "auto", "defaults,nofail", "0", "0" ]
EOF

openstack volume create \
--size 5 \
ftp-volume-01 && \
ftp_volume_01_id=$(openstack volume show ftp-volume-01 -c id -f value) && \
echo "ftp_volume_01_id="$ftp_volume_01_id

openstack server create \
--image centos7 \
--flavor m1.small \
--key-name director \
--port port-51 \
--user-data /osp/cloud-init/ftp-51.yml \
--block-device-mapping vdb=$ftp_volume_01_id:volume:5:false \
--wait \
ftp-51

openstack volume create \
--size 5 \
ftp-volume-02

ssh centos@192.168.1.51

sudo parted /dev/vdc \
mklabel msdos \
mkpart primary ext4 1M 5G

sudo mkfs.ext4 /dev/vdc1

sudo mkdir /mnt/volume-02

sudo mount -t ext4 /dev/vdc1 /mnt/volume-02

vdc1_uuid=$(lsblk -fl --output NAME,UUID | grep vdc1 | awk '{ print $2 }') && \
fstab_line=$(echo "UUID=$vdc1_uuid /mnt/volume-02 auto defaults,nofail 0 0") && \
echo $fstab_line

sudo su -c "echo $fstab_line >> /etc/fstab"

#Populate Ceilometer Database

su -s /bin/sh -c "aodh-dbsync --config-file=/etc/aodh/aodh.conf" aodh

sudo chown -R aodh:aodh /var/log/aodh/

openstack metric list

openstack alarm list

instance_id=$(openstack server show ftp-31 -c id -f value)

openstack alarm create \
--name cpu_hi -t gnocchi_resources_threshold \
--description 'instance running hot' \
--enabled True \
--alarm-action 'log://' \
--comparison-operator gt \
--evaluation-periods 1 \
--threshold 70.0 \
--metric cpu_util \
--granularity 300 \
--aggregation-method mean \
--resource-type instance \
--resource-id $instance_id

openstack alarm list

openstack alarm-history show --fit-width f09d76e7-8d25-44cf-ae58-4003e61759d5

# Heat

openstack orchestration template version list

openstack orchestration resource type list

openstack orchestration resource type show OS::Nova::Server

# Oracle Express

openstack security group create \
--project $openstack_project \
--description "Oracle Database Express Security Group" \
devel_oracle_xe_sg

openstack security group rule create \
--proto icmp \
--remote-ip 0.0.0.0/0 \
--dst-port -1 \
devel_oracle_xe_sg

openstack security group rule create \
--protocol tcp \
--remote-ip 0.0.0.0/0 \
--dst-port 22 \
devel_oracle_xe_sg

openstack security group rule create \
--proto tcp \
--remote-ip 0.0.0.0/0 \
--dst-port 1521 \
devel_oracle_xe_sg

openstack port create \
--disable-port-security \
--no-security-group \
--fixed-ip subnet=$openstack_internal_subnet_id,ip-address=10.0.0.40 \
--network $openstack_internal_network_id \
port-oracle-xe-prd

openstack port create \
--disable-port-security \
--no-security-group \
--fixed-ip subnet=$openstack_internal_subnet_id,ip-address=10.0.0.41 \
--network $openstack_internal_network_id \
port-oracle-xe-hml

openstack floating ip create \
--project $openstack_project \
--port port-oracle-xe-prd \
--floating-ip-address 192.168.1.40 \
$openstack_public_network_id

openstack floating ip create \
--project $openstack_project \
--port port-oracle-xe-hml \
--floating-ip-address 192.168.1.41 \
$openstack_public_network_id

for server in master-0 node-1 node-2; do
  openstack server create \
  --image centos7 \
  --flavor m1.small \
  --key-name director \
  --port port-oracle-xe-$env \
  --security-group devel_oracle_xe_sg \
  --wait \
  oracle-xe-$env;
done

openstack server create \
--image centos7 \
--flavor m1.small \
--key-name director \
--port port-oracle-xe-hml \
--security-group devel_oracle_xe_sg \
oracle-xe-hml

openstack_public_network_id=$(openstack network show public_network -c id -f value)

openstack_internal_network_id=$(openstack network show $openstack_internal_network -c id -f value)

openstack_internal_subnet_id=$(openstack subnet show devel_subnet -c id -f value)

openstack server create \
--image centos7 \
--flavor m1.large \
--key-name director \
--nic net-id=$openstack_internal_network_id \
--security-group devel_oracle_xe_sg \
oracle-xe-prd
