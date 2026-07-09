#!/bin/bash
set -e
PASSWORD=kafkapractice
DAYS=365

mkdir -p certs && cd certs

openssl req -new -x509 -keyout ca-key -out ca-cert -days $DAYS \
  -subj "/CN=kafka-practice-ca" -passout pass:$PASSWORD

keytool -keystore broker.keystore.jks -alias broker -validity $DAYS -genkey -keyalg RSA \
  -dname "CN=kafka1" -storepass $PASSWORD -keypass $PASSWORD
keytool -keystore broker.keystore.jks -alias broker -certreq -file broker.csr -storepass $PASSWORD
openssl x509 -req -CA ca-cert -CAkey ca-key -in broker.csr -out broker-signed.crt \
  -days $DAYS -CAcreateserial -passin pass:$PASSWORD
keytool -keystore broker.keystore.jks -alias caroot -import -file ca-cert -storepass $PASSWORD -noprompt
keytool -keystore broker.keystore.jks -alias broker -import -file broker-signed.crt -storepass $PASSWORD -noprompt
keytool -keystore broker.truststore.jks -alias caroot -import -file ca-cert -storepass $PASSWORD -noprompt

keytool -keystore client.keystore.jks -alias client -validity $DAYS -genkey -keyalg RSA \
  -dname "CN=client" -storepass $PASSWORD -keypass $PASSWORD
keytool -keystore client.keystore.jks -alias client -certreq -file client.csr -storepass $PASSWORD
openssl x509 -req -CA ca-cert -CAkey ca-key -in client.csr -out client-signed.crt \
  -days $DAYS -CAcreateserial -passin pass:$PASSWORD
keytool -keystore client.keystore.jks -alias caroot -import -file ca-cert -storepass $PASSWORD -noprompt
keytool -keystore client.keystore.jks -alias client -import -file client-signed.crt -storepass $PASSWORD -noprompt
keytool -keystore client.truststore.jks -alias caroot -import -file ca-cert -storepass $PASSWORD -noprompt

echo "Done. Keystores/truststores are in $(pwd)"
