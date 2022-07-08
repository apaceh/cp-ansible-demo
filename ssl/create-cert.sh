#!/usr/bin/bash

#set -o nounset \
#    -o errexit \
#    -o verbose \
#    -o xtrace

# Cleanup files
rm -f *.crt *.csr *_creds *.jks *.srl *.key *.pem *.der *.p12 *.log

# Generate CA key
openssl req -new -x509 -keyout snakeoil-ca-1.key -out snakeoil-ca-1.crt -days 365 -subj '/CN=*.alfi.com/OU=FS/O=ADI/L=JAKBAR/ST=DKI/C=ID' -passin pass:confluent -passout pass:confluent

# ksqlDB Server (ksqldb-server) and Control Center (control-center) share a commom certificate; a separate certificate is not generated for ksqldb-server
# this shared certificate has a self-signed CA - when control-center presents the certificate to a browser visiting control-center at https://localhost:9092 ,
# it can be accepted without importing and trusting the self-signed CA, and this acceptance will also apply later to WebSockets requests to wss://localhost:8089
# (port-forwarded to ksqldb-server:8089), serving the same certificate from ksqldb-server.
#
# This is necessary as browsers never prompt to trust certificates for this kind of wss:// connection, see https://stackoverflow.com/a/23036270/452210 .
#
users=(broker1.alfi.com broker2.alfi.com broker3.alfi.com)
echo "Creating certificates"
printf '%s\0' "${users[@]}" | xargs -0 -I{} -n1 -P15 sh -c './certs-create-per-user.sh "$1" > "certs-create-$1.log" 2>&1 && echo "Created certificates for $1"' -- {}
echo "Creating certificates completed"
