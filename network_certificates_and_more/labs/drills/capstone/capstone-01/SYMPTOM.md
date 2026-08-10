# Capstone 01 — Symptom

IT hands you `ca/root/certs/ca.cert.pem` and says "here's the CA cert for
`reports.local`, use this to verify it." You ran, from `labs/`:

```
docker compose run --rm toolbox bash /work/drills/capstone/capstone-01/repro.sh
```

That script issues a fresh `reports.local` certificate from your real
intermediate CA, serves it from a throwaway `openssl s_server`, then runs
this `curl` against it (the exact command IT's instructions told you to
run, adapted to this lab's `--connect-to` convention):

```
curl --cacert /work/ca/root/certs/ca.cert.pem \
     --connect-to reports.local:8600:127.0.0.1:8600 \
     https://reports.local:8600/
```

Observed output:

```
curl: (60) SSL certificate problem: unable to get local issuer certificate
More details here: https://curl.se/docs/sslcerts.html

curl failed to verify the legitimacy of the server and therefore could not
establish a secure connection to it. To learn more about this situation and
how to fix it, please visit the web page mentioned above.
```

You confirmed `ca/root/certs/ca.cert.pem` really is your CA's root
(`openssl x509 -in /work/ca/root/certs/ca.cert.pem -noout -subject` prints
`CN = TLS Mastery Root CA`) — it is not the wrong file, and it is not
expired.
