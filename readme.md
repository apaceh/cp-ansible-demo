# Setup Confluent Using Ansible

This is instruction to run confluent cluster automatically via ansible. Original documentation can be foudn [here](https://docs.confluent.io/ansible/current/overview.html).


## Prerequisite
We need 5 machine to run this demo. One machine for ansible control node, one machine for kerberos and openldap server and three others for confluent host.
|     Hostname      |  IP Address  |    OS    |      Description        |
|-------------------|--------------|----------|-------------------------|
| ans.alfi.com      | 172.18.46.10 | Centos 7 | Ansible control node    |
| broker1.alfi.com  | 172.18.46.11 | Centos 7 | Confluent first node    |
| broker2.alfi.com  | 172.18.46.12 | Centos 7 | Confluent second node   |
| broker3.alfi.com  | 172.18.46.13 | Centos 7 | Confluent third node    |
| kerberos.alfi.com | 172.18.46.14 | Centos 7 | Kerberos and ldap node  |

For Kerberos and ldap configuration, you can follow this instruction : [link](krb_ldap/setup_krb5_ldap.md)
Make sure all node is connected and **ssh** installed.

Below is list of kerberos principal we will use:
|        Kerberos Principal       |      Keytab Name      |
|---------------------------------|-----------------------|
| kafka/broker1.alfi.com          | allprinc.keytab       |
| kafka/broker2.alfi.com          | allprinc.keytab       |
| kafka/broker3.alfi.com          | allprinc.keytab       |
| zookeeper/broker1.alfi.com      | allprinc.keytab       |
| zookeeper/broker2.alfi.com      | allprinc.keytab       |
| zookeeper/broker3.alfi.com      | allprinc.keytab       |
| connect/broker1.alfi.com        | connect.keytab        |
| ksql/broker1.alfi.com           | ksql.keytab           |
| schemaregistry/broker1.alfi.com | schemaregistry.keytab |
| restproxy/broker1.alfi.com      | restproxy.keytab      |
| controlcenter/broker1.alfi.com  | controlcenter.keytab  |

Put all keytab file at /tmp/keytabs/.

Below is list of LDAP principal we will use:
|               LDAP Principal               | Object Class | memberOf |
|--------------------------------------------|--------------|----------|
| cn=kafkadev,ou=people,dc=alfi,dc=com       | groupOfNames |    -     |
| cn=kafka_broker,ou=people,dc=alfi,dc=com   | person       | kafkadev |
| cn=mds,ou=people,dc=alfi,dc=com            | person       | kafkadev |
| cn=connect,ou=people,dc=alfi,dc=com        | person       | kafkadev |
| cn=schemaregistry,ou=people,dc=alfi,dc=com | person       | kafkadev |
| cn=restproxy,ou=people,dc=alfi,dc=com      | person       | kafkadev |
| cn=ksql,ou=people,dc=alfi,dc=com           | person       | kafkadev |
| cn=controlcenter,ou=people,dc=alfi,dc=com  | person       | kafkadev |

## Generate SSH Keypair
Execute command below to generate ssh keypair for confluent host, so you can login to all confluent host without password.

```bash
[root@ans ~]# ssh-keygen
[root@ans ~]# ssh-copy-id root@broker1.alfi.com
[root@ans ~]# ssh-copy-id root@broker2.alfi.com
[root@ans ~]# ssh-copy-id root@broker3.alfi.com
[root@ans ~]# ssh-agent bash
[root@ans ~]# ssh-add ~/.ssh/id_rsa
[root@ans ~]# mkdir /tmp/certs/
[root@ans ~]# openssl rsa -in ~/.ssh/id_rsa -outform pem > /tmp/certs/ssh_priv.pem
```

## Generate custom certificate for each confluent host
```bash
[root@ans ~]# mkdir /tmp/certs/ssl
[root@ans ~]# cd /tmp/certs/ssl
[root@ans ~]# mkdir ssl
[root@ans ~]# cd ssl
[root@ans ~]# vim create-cert.sh
```
The contents of `create-cert.sh` file can be seen [here](ssl/create-cert.sh).
```bash
[root@ans ~]# vim certs-create-per-user.sh
```
The contents of `certs-create-per-user.sh` file can be seen [here](ssl/certs-create-per-user.sh).
```bash
[root@ans ~]# chmod +x create-cert.sh
[root@ans ~]# chmod +x certs-create-per-user.sh
[root@ans ~]# ./create-cert.sh
```
Note
: if shown error such as `bash: ./create-cert.sh: /usr/bin/bash^M: bad interpreter: No such file or directory`. Run this command: `sed -i -e 's/\r$//' create-cert.sh && sed -i -e 's/\r$//' certs-create-per-user.sh`.

## Create a PEM key pair
Documentation to generate rbac keypair can be found [here](https://docs.confluent.io/platform/current/kafka/configure-mds/index.html#create-a-pem-key-pair).
```bash
[root@ans ~]# cd /tmp/certs
[root@ans ~]# openssl genrsa -out /tmp/certs/tokenKeypair.pem 2048
[root@ans ~]# openssl rsa -in /tmp/certs/tokenKeypair.pem -outform PEM -pubout -out /tmp/certs/tokenPublicKey.pem
```

## Install Ansible on Control Host
```bash
[root@ans ~]# yum install epel-release -y
[root@ans ~]# yum -y install ansible git
[root@ans ~]# ansible --version
[root@ans ~]# ansible-galaxy collection install community.general:==4.8.1
```

## Firewall setting
We need to configure firewall to open access for ports exposed by confluent. See this [documentation](https://docs.confluent.io/platform/current/installation/system-requirements.html#ports) for details.
```bash
[root@ans ~]# vim firewalld-inventory
```
The contents of `firewalld-inventory` file can be seen [here](firewall/firewalld-inventory).
```bash
[root@ans ~]# vim firewalld-playbook.yml
```
The contents of `firewalld-playbook.yml` file can be seen [here](firewall/firewalld-playbook.yml).
```bash
[root@ans ~]# ansible-playbook -i firewalld-inventory firewalld-playbook.yml
```


## Setup cp-ansible
```bash
[root@ans ~]# mkdir -p ansible/ansible_collections/confluent/
[root@ans ~]# git clone https://github.com/confluentinc/cp-ansible ansible/ansible_collections/confluent/platform
[root@ans ~]# cd ansible/ansible_collections/confluent/platform/
[root@ans ~]# vim hosts.yml
```
The contents of `hosts.yml` file can be seen [here](ansible-host.yml).
```bash
// verify connection to host.
[root@ans ~]# ansible -i hosts.yml all -m ping
[root@ans ~]# ansible-playbook -i hosts.yml playbooks/all.yml

// to rolling reconfigure
[root@ans ~]# ansible-playbook -i hosts.yml playbooks/all.yml --skip-tags package --extra-vars deployment_strategy=rolling

// to stop service on remote host via ansible
[root@ans ~]# ansible -i hosts.yml all -m shell -a 'systemctl stop confluent-*'
```

## Access control center in browser
[https://172.18.46.11:9021](https://172.18.46.11:9021)

Control center user:
```
username : controlcenter
password : password
```
