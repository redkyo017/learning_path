# Drill 13 — Symptom

A teammate hands you `client01-wrongca.cert.pem` and `client01-wrongca.key.pem`
(both in this directory) and says "this is your client identity for the mTLS
service, go ahead and connect." You point your mTLS curl command at
`nginx-mtls.conf`'s server (the same one from today's guided lab) using this
cert/key pair instead of the `client01` cert you issued yourself from the
lab's real CA:

```
docker compose run --rm toolbox curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
    --cert /work/drills/drill-13/client01-wrongca.cert.pem \
    --key /work/drills/drill-13/client01-wrongca.key.pem \
    --connect-to example.local:8443:nginx:443 \
    https://example.local:8443/
```

Observed output (curl exit code `0` — the TLS handshake completed; the
rejection is an HTTP `400`):

```
<html>
<head><title>400 The SSL certificate error</title></head>
<body>
<center><h1>400 Bad Request</h1></center>
<center>The SSL certificate error</center>
<hr><center>nginx/1.30.5</center>
</body>
</html>
```

nginx's own error log (`docker compose logs nginx`) shows a line resembling:

```
[info] ... client SSL certificate verify error: (21:unable to verify the first certificate) while reading client request headers, client: ...
```

curl verified nginx's certificate fine with the same `--cacert` (you got an
HTTP answer at all), so the server side of the handshake is not in question
here. This drill is entirely about the client side.

Also present in this directory: `rogue-ca.cert.pem` and
`reference-ca.cert.pem`. You have not been told what either of those is for.
