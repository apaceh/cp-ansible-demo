# Setup Kerberos AND OpenLDAP

This is instruction to configure kerberos server and openldap server. This instruction will use one host machine with Centos 7 installed.

## Kerberos configuration
```bash
[root@kerberos ~]# yum install krb5-server
[root@kerberos ~]# vim /etc/krb5.conf
```

Change domain in `krb5.conf` like this :
```bash
# Configuration snippets may be placed in this directory as well
includedir /etc/krb5.conf.d/

[logging]
 default = FILE:/var/log/krb5libs.log
 kdc = FILE:/var/log/krb5kdc.log
 admin_server = FILE:/var/log/kadmind.log

[libdefaults]
 dns_lookup_realm = false
 ticket_lifetime = 24h
 # renew_lifetime = 7d
 forwardable = true
 rdns = false
 pkinit_anchors = FILE:/etc/pki/tls/certs/ca-bundle.crt
 default_realm = ALFI.COM
 default_ccache_name = KEYRING:persistent:%{uid}

[realms]
 ALFI.COM = {
  kdc = kerberos.alfi.com
  admin_server = kerberos.alfi.com
 }

[domain_realm]
 .alfi.com = ALFI.COM
 alfi.com = ALFI.COM
```

```bash
[root@kerberos ~]# vim /var/kerberos/krb5kdc/kdc.conf
```

Change `EXAMPLE.COM` in `kdc.conf` to your domain :
```bash
[kdcdefaults]
 kdc_ports = 88
 kdc_tcp_ports = 88

[realms]
 ALFI.COM = {
  #master_key_type = aes256-cts
  acl_file = /var/kerberos/krb5kdc/kadm5.acl
  dict_file = /usr/share/dict/words
  admin_keytab = /var/kerberos/krb5kdc/kadm5.keytab
  supported_enctypes = aes256-cts:normal aes128-cts:normal des3-hmac-sha1:normal arcfour-hmac:normal camellia256-cts:normal camellia128-cts:normal des-hmac-sha1:normal des-cbc-md5:normal des-cbc-crc:normal
 }

```

```bash
[root@kerberos ~]# vim /var/kerberos/krb5kdc/kadm5.acl
```

Change `EXAMPLE.COM` in `kadm5.conf` to your domain :
```bash
*/admin@ALFI.COM  *
```

```bash
[root@kerberos ~]# kdb5_util create -s -r ALFI.COM
[root@kerberos ~]# systemctl enable kadmin
[root@kerberos ~]# systemctl enable krb5kdc
[root@kerberos ~]# systemctl start kadmin
[root@kerberos ~]# systemctl start krb5kdc
[root@kerberos ~]# firewall-cmd --permanent --add-admin kerberos
[root@kerberos ~]# firewall-cmd --reload
```

## Create Kerberos Principal
```bash
[root@kerberos ~]# kadmin.local
kadmin.local: addprinc root/admin
kadmin.local: addprinc ldap/kerberos.alfi.com
kadmin.local: ktadd -k /tmp/ldap.keytab ldap/kerberos.alfi.com
kadmin.local: q
[root@kerberos ~]# chmod 777 /tmp/ldap.keytab
```

## OpenLDAP Configuration
```bash
[root@kerberos ~]# yum install -y openldap openldap-servers openldap-clients cyrus-sasl
[root@kerberos ~]# chown -R ldap /var/lib/ldap/
[root@kerberos ~]# slappasswd
[root@kerberos ~]# vim ldaprootpasswd.ldif
```
Contents of file `ldaprootpasswd.ldif`:
```bash
dn: olcDatabase={0}config,cn=config
changetype: modify
add: olcRootPW
olcRootPW: #put password shown from slappasswd
```

```bash
[root@kerberos ~]# vim ldapdomain.ldif
```
Contents of file `ldapdomain.ldif`:
```bash
dn: olcDatabase={1}monitor,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" read by dn.base="cn=admin,dc=alfi,dc=com" read by * none

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcSuffix
olcSuffix: dc=alfi,dc=com

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcRootDN
olcRootDN: cn=admin,dc=alfi,dc=com

dn: olcDatabase={2}hdb,cn=config
changetype: modify
add: olcRootPW
olcRootPW: {SSHA}T957wWSbt2tUv343CTU2Hq7mTSraVvEa

dn: olcDatabase={2}hdb,cn=config
changetype: modify
add: olcAccess
olcAccess: {0}to attrs=userPassword,shadowLastChange by dn="cn=admin,dc=alfi,dc=com" write by anonymous auth by self write by * none
olcAccess: {1}to dn.base="" by * read
olcAccess: {2}to * by dn="cn=admin,dc=alfi,dc=com" write by * read
```

```bash
[root@kerberos ~]# ldapadd -Y EXTERNAL -H ldapi:/// -f ldaprootpasswd.ldif
[root@kerberos ~]# ldapmodify -Y EXTERNAL -H ldapi:/// -f ldapdomain.ldif
[root@kerberos ~]# ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
[root@kerberos ~]# ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
[root@kerberos ~]# ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif
[root@kerberos ~]# ldapadd -x -D cn=admin,dc=alldataint,dc=com -W -f baseldapdomain.ldif
```

To activate memberOf overlay for our ldap server, follow these instruction:

```bash
[root@kerberos ~]# vim memberof.ldif
```
Contents of file `memberof.ldif`:
```bash
dn: cn=module,cn=config
cn: module
objectClass: olcModuleList
objectClass: top
olcModulePath: /usr/lib64/openldap

dn: olcOverlay={0}memberof,olcDatabase={2}hdb,cn=config
objectClass: olcConfig
objectClass: olcMemberOf
objectClass: olcOverlayConfig
objectClass: top
olcOverlay: memberof
olcMemberOfDangling: ignore
olcMemberOfRefInt: TRUE
olcMemberOfGroupOC: groupOfNames
olcMemberOfMemberAD: member
olcMemberOfMemberOfAD: memberOf
```

```bash
[root@kerberos ~]# vim refint1.ldif
```
Contents of file `refint1.ldif`:
```bash
dn: cn=module,cn=config
cn: module
objectclass: olcModuleList
objectclass: top
olcmodulepath: /usr/lib64/openldap

dn: olcOverlay={1}refint,olcDatabase={2}hdb,cn=config
objectClass: olcConfig
objectClass: olcOverlayConfig
objectClass: olcRefintConfig
objectClass: top
olcOverlay: {1}refint
olcRefintAttribute: memberof member manager owner
```

```bash
[root@kerberos ~]# vim refint2.ldif
```
Contents of file `refint2.ldif`:
```bash
dn: olcOverlay={1}refint,olcDatabase={2}hdb,cn=config
objectClass: olcConfig
objectClass: olcOverlayConfig
objectClass: olcRefintConfig
objectClass: top
olcOverlay: {1}refint
olcRefintAttribute: memberof member manager owner
```

```bash
[root@kerberos ~]# ldapadd -Q -Y EXTERNAL -H ldapi:/// -f memberof.ldif
[root@kerberos ~]# ldapadd -Q -Y EXTERNAL -H ldapi:/// -f refint1.ldif
[root@kerberos ~]# ldapadd -Q -Y EXTERNAL -H ldapi:/// -f refint2.ldif
```

```bash
[root@kerberos ~]# 
[root@kerberos ~]# vim baseldapdomain.ldif
```
Contents of file `baseldapdomain.ldif`:
```bash
dn: dc=alldataint,dc=com
objectClass: top
objectClass: dcObject
objectclass: organization
o: alldataint com
dc: alldataint

dn: ou=people,dc=alldataint,dc=com
objectClass: organizationalUnit
ou: people
```

```bash
[root@kerberos ~]# systemctl enable slapd
[root@kerberos ~]# systemctl start slapd
[root@kerberos ~]# firewall-cmd --permanent --add-service=ldap
[root@kerberos ~]# firewall-cmd --reload
[root@kerberos ~]# ldapadd -x -D cn=admin,dc=alldataint,dc=com -W -f baseldapdomain.ldif
```

## Enable gssapi mechanism for ldap
```bash
[root@kerberos ~]# vim /etc/sasl2/slapd.conf
```
Contents of file `slapd.conf`:
```bash
keytab: /tmp/ldap.keytab
mech_list: CRAM-MD5 DIGEST-MD5 GSSAPI EXTERNAL
[root@kerberos ~]#systemctl restart slapd
```

Show support mechanism using this command:
```bash
[root@kerberos ~]# ldapsearch -LLL -x -H ldap://kerberos.alfi.com -s "base" -b "" supportedSASLMechanisms
```

## Create LDAP Account
Use Apache Directory Studio to create LDAP Account.
