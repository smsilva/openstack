# OpenStack

Este repositório contém informações relacionadas ao meu aprendizado sobre OpenStack.

Os scripts aqui mostrados foram testados usando o release Queens do projeto RDO.

https://www.rdoproject.org/

## Hardware

O Hardware usado para montar meu laboratório foi:

**1. Roteador Cisco LinkSys E900**

```
CIDR.............................: 192.168.1.0/24
Endereço IP do roteador..........: 192.168.1.1
Endereço IP reservado para o NUC.: 192.168.1.101
```

**2. Mini PC Intel NUC 6I7KYK Skull Canyon**

```
Processador..: I7-6770HQ 3.5 GHZ
Memória RAM..: 32 GB
Disco rígido.: Crucial Mx500 1 TB SS2 M.2 2280
```

**3. PenDrive**

O PenDrive será usado apenas para a instalação do CentOS 7.

# Instalação

## 1. Roteador

Primeiro resetei o roteador LinkSys às configurações de fábrica.

Em seguida, configurei uma senha no roteador para acesso administrativo e conectei o mesmo ao meu roteador do provedor de internet (porta LAN do roteador com acesso à internet à porta WAN do LinkSys).

Em seguida conectei o roteador ao NUC usando um cabo de rede.

## 2. CentOS 7

Instalaremos o CentOS 7 no NUC.

### 2.1. Download CentOS 7 Minimal ISO Image

http://isoredirect.centos.org/centos/7/isos/x86_64/CentOS-7-x86_64-Minimal-1804.iso

### 2.2. Criação de um PenDrive de Boot

Como ainda preciso usar Windows no trabalho usei o Rufus para criar um PenDrive de boot.

https://rufus.akeo.ie/

### 2.3. Instalando o CentOS 7

Durante a Instalação do CentOS 7, alterei os seguintes parâmetros:

**Localization Date/Time:** Americas/Sao Paulo timezone

**Network & Hostname:** Habilitei a placa de rede para que já obtivesse um IP do roteador. Esse IP deixei reservado nas configurações de DHCP do roteador. No caso: **192.168.1.101**.

**Installation destination:** Marquei a opção "I will configure partitioning"

```
  /boot     xfs  256 MiB
  /boot/efi xfs  256 MiB
  /swap     swap  16 GiB
  /home     ext4  40 GiB
  /         ext4 500 GiB
  /osp      ext4 100 GiB

```

Pode prosseguir com o restante da instalação, informe uma senha para o usuário root e ao final, lembre-se de retirar o PenDrive e reiniciar o NUC.

### 2.4 Configurando um par de chaves para facilitar o acesso ao NUC

Para gerar um par de chaves, você pode seguir o ótimo tutorial da Digital Ocean:

https://www.digitalocean.com/community/tutorials/initial-server-setup-with-centos-7

Caso pretenda acessar a partir do Windows, recomendo usar o Putty e que tenha instalado o Git para usar o Git Bash.

Usando o Git Bash, você será capaz de gerar seu par de chaves no Windows.

Após gerar as chaves, pode usar o PuTTY Key Generator no Windows para criar um arquivo com extensão PPK que pode ser usado em conjunto com o PuTTY para acessar o ambiente sem precisar sempre digitar a senha.

## 3. Configurações iniciais do NUC ##

Se tiver problemas com lentidão ao conectar via SSH, você pode desativar o uso de DNS para essa conexão:

```
sed -i 's/#UseDNS yes/UseDNS no/g' /etc/ssh/sshd_config
```

**Atualize o sistema:**

```
yum update -y
```

**Altere o Hostname do NUC**

```
hostnamectl set-hostname openstack.example.com
```

**Configure a placa de rede para que fique com o IP fixo**

No arquivo:

```
/etc/sysconfig/network-scripts/ifcfg-eno1
```

Altere o Protocolo de Boot para Static:

```
BOOTPROTO=static
```

Acrescente as linhas:

```
IPADDR=192.168.1.101
NETMASK=255.255.255.0
GATEWAY=192.168.1.1
DNS1=192.168.1.1
```

Reinicie o NUC para testar a conectividade após o boot.

```
reboot
```

**Instale o Repositório Extra Packages for Enterprise Linux (EPEL)**

```
yum install epel-release -y
```

**Instale o Git e o Ansible**

```
yum install git ansible -y
```

Configure o Ansible para exibir o tempo de execução de cada tarefa executada:

```
sed -i 's/#callback_whitelist = timer, mail/callback_whitelist = profile_tasks, timer/g' /etc/ansible/ansible.cfg
```

Configura o local do arquivo de log

```
sed -i 's/#log_path = /log_path = /g' /etc/ansible/ansible.cfg
```

Configura o local das Roles

```
sed -i 's/#roles_path/roles_path/g' /etc/ansible/ansible.cfg
```

## 4. Instalação usando PackStack ##

Clone o repositório que contém os Playbooks Ansible:

```
git clone https://github.com/smsilva/openstack.git
```

Acesse o diretório de instalação:

```
cd openstack/install/
```

Teste para verificar a conectividade com o servidor onde o OpenStack será instalado:

```
ansible -i hosts.yml -m ping osp
```

Resultado esperado:

```
openstack.example.com | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

Configuração e Instalação usando PackStack:

```
ansible-playbook -i hosts.yml install.yml
```

A duração da instalação é de aproximadatamente 25 minutos com a minha conexão de internet (15 Mbps).
