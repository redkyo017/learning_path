# Day 4 Lab: Solution & Explanations

Output below was captured on Docker Desktop Kubernetes 1.34.3 (kind provisioner, node `desktop-control-plane`, kindnet, kube-proxy `iptables`), Envoy Gateway v1.9.2, Helm 4.3.0. Pod IPs, hashes and timestamps differ on your machine; shapes and counts should match.

## Step 2: Envoy Gateway

```text
$ kubectl wait -n envoy-gateway-system --timeout=120s --for=condition=Available deployment/envoy-gateway
deployment.apps/envoy-gateway condition met
$ kubectl get crd | grep gateway.networking.k8s.io | awk '{print $1}'
backendtlspolicies.gateway.networking.k8s.io
gatewayclasses.gateway.networking.k8s.io
gateways.gateway.networking.k8s.io
grpcroutes.gateway.networking.k8s.io
httproutes.gateway.networking.k8s.io
listenersets.gateway.networking.k8s.io
referencegrants.gateway.networking.k8s.io
tcproutes.gateway.networking.k8s.io
...
```
The chart `oci://docker.io/envoyproxy/gateway-helm` version `v1.9.2` installed as written (Gateway API CRDs included). The chart installs the Gateway API CRDs cluster-wide at v1.6.1 from the **experimental** channel (which is why `tcproutes` and the `x-k8s.io` types are present; since Gateway API v1.5 the *standard* channel has GatewayClass, Gateway, HTTPRoute, GRPCRoute, ReferenceGrant, BackendTLSPolicy, TLSRoute and ListenerSet, and the experimental one adds TCPRoute/UDPRoute and the alpha types). The CRD list contains more entries than shown.

## Step 3: Gateway, route, access from the Mac

```text
$ kubectl get gateway -n gateway-infra
NAME   CLASS   ADDRESS      PROGRAMMED   AGE
edge   eg      172.21.0.5   True         29s

$ kubectl get pods,svc -n envoy-gateway-system
pod/envoy-gateway-68b9c796c4-2k8j4                       1/1   Running
pod/envoy-gateway-infra-edge-b9ff91e8-69b96796b5-zdfnk   2/2   Running
service/envoy-gateway-infra-edge-b9ff91e8   LoadBalancer   10.96.229.74   172.21.0.5   80:30796/TCP

$ curl -i http://localhost/orders
HTTP/1.1 200 OK
content-type: application/json
content-length: 3

[]
$ curl -i http://localhost/payments
HTTP/1.1 404 Not Found
content-length: 0
```
* The proxy pods run in **`envoy-gateway-system`** (label `gateway.envoyproxy.io/owning-gateway-name=edge`), not in `gateway-infra`. The Gateway's `ADDRESS` is the LoadBalancer IP assigned by Docker Desktop's cloud provider helper; **`172.21.0.5` is not reachable from the Mac** (`curl` to it times out) but Docker Desktop publishes the Service's port 80 on **`localhost:80`**, which is what the lab uses. `kubectl port-forward -n envoy-gateway-system svc/<proxy-svc> 8888:80` also returned 200 (fallback).
* The pod is `2/2`: the Envoy container plus Envoy Gateway's shutdown-manager sidecar.
* Route status: `Accepted=True Accepted`, `ResolvedRefs=True ResolvedRefs`.
* Payment is protected by **omission**: no route matches `/payments`, Envoy returns 404. (The old Ingress exposed `/api/payments`; that was a mistake, and the old rewrite `/$2` also sent `/api/orders` to `/`.)

## Step 4: header match and weighted canary

Pods: `order-api` x2 (`10.244.0.70`, `10.244.0.71`), canary `10.244.0.78`.
```text
# 100 plain requests (90/10 weighting; chance varies per run):
  39 "upstream_host":"10.244.0.70:8080"
  51 "upstream_host":"10.244.0.71:8080"
  10 "upstream_host":"10.244.0.78:8080"
# 10 requests with -H 'x-canary: true':
  10 "upstream_host":"10.244.0.78:8080"
```
Envoy's access log (JSON on stdout) also carries `route_name` (`.../rule/0/match/0` = header rule, `rule/1` = weighted rule) and `response_code`. The 90 requests split between the two `order-api` pods is Envoy's own balancing across the weighted cluster's endpoints; it does not use the ClusterIP.

## Step 5: BREAK IT

```text
$ kubectl get endpointslices -n orderflow -l kubernetes.io/service-name=order-api    # selector: non-existent
NAME              ADDRESSTYPE   PORTS     ENDPOINTS   AGE
order-api-xg56r   IPv4          <unset>   <unset>     108s
$ curl -i http://localhost/orders
HTTP/1.1 503 Service Unavailable
content-length: 0
$ kubectl get httproute orderflow -n orderflow -o jsonpath=...
Accepted=True Accepted
BackendsAvailable=False EndpointsNotFound
ResolvedRefs=True ResolvedRefs

# targetPort: 9999 (numeric, wrong)
NAME              PORT   ADDRS
order-api-xg56r   9999   10.244.0.70,10.244.0.71
$ curl -s http://localhost/orders
upstream connect error or disconnect/reset before headers. reset reason: remote connection failure
```
The first case empties the slice (selector matches nothing). The second keeps both addresses: the EndpointSlice controller never checks that anything listens on the port. A wrong *named* `targetPort` would instead produce an empty slice.

## Step 6: headless DNS

```text
$ kubectl exec -n orderflow dns-test -- nslookup payment-service-headless.orderflow.svc.cluster.local.
Name:	payment-service-headless.orderflow.svc.cluster.local
Address: 10.244.0.68
Name:	payment-service-headless.orderflow.svc.cluster.local
Address: 10.244.0.67
$ kubectl exec -n orderflow dns-test -- nslookup payment-service.orderflow.svc.cluster.local.
Name:	payment-service.orderflow.svc.cluster.local
Address: 10.96.202.204
$ kubectl exec -n orderflow dns-test -- cat /etc/resolv.conf
search orderflow.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5
$ kubectl get endpointslices -n orderflow
notification-service-hfg4d       IPv4   8082   10.244.0.69
order-api-xg56r                  IPv4   8080   10.244.0.70,10.244.0.71
payment-service-crdfd            IPv4   8081   10.244.0.67,10.244.0.68
payment-service-headless-2fs4x   IPv4   8081   10.244.0.68,10.244.0.67
```
The headless answer is the pod IPs (order is not stable: clients should not depend on it); the ClusterIP name returns one virtual IP. Headless needs client-side balancing (or just DNS-based discovery of individual peers). The IPs match `kubectl get pods -o wide`.

## Step 7: NetworkPolicy

```text
# before policies, notification -> payment
code=200
# after kubectl apply -f labs/day04/manifests/networkpolicy.yaml
$ kubectl get networkpolicy -n orderflow
NAME                              POD-SELECTOR               AGE
allow-edge-to-order-api           app=order-api              14s
allow-order-api-to-notification   app=notification-service   14s
allow-order-api-to-payment        app=payment-service        14s
default-deny-all-ingress          <none>                     14s

edge: 200
{"status":"ok","service":"payment-service"} code=200            # from the order-api pod
{"status":"ok","service":"notification-service"} code=200
curl: (28) Connection timed out after 3002 milliseconds         # from the notification pod
code=000
POST: 201      # notification-service logs: dispatching notification for order ...
```
* The packet is **dropped**, not rejected: no RST or ICMP, so the client waits for its own timeout (`exit 28`, `code=000`).
* Edge → order-api works because `allow-edge-to-order-api` admits pods labelled `app.kubernetes.io/name=envoy` + `gateway.envoyproxy.io/owning-gateway-name=edge` **in `envoy-gateway-system`** (one `from` item, AND).
* Before the fix for D4-5, default-deny blocked `order-api → notification-service` (no allow existed) so every POST logged a notify failure. `allow-order-api-to-notification` fixes it: the logs show `dispatching notification` for each order.
* Pods stayed `1/1 Running` throughout: kubelet probes are not blocked by these policies on kindnet.
* The ephemeral containers (`open-test`, `deny-test`, ...) remain listed in the pod spec; they exit and cannot be removed individually.

## Step 8: egress default-deny

```text
$ kubectl apply -f - <<'YAML'   # default-deny-all-egress heredoc from Step 8
POST: 201
[order-api] call to /payments failed for order ea0aee0c7d5d2faf: Post "http://payment-service:8081/payments": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
[order-api] call to /notify   failed for order ea0aee0c7d5d2faf: Post "http://notification-service:8082/notify": context deadline exceeded ...
# after kubectl apply -f labs/day04/manifests/networkpolicy-egress.yaml (+ ~8 s)
3 x POST ... -> three new "dispatching notification" lines in notification-service; no new failures
```
`order-api` answers `201` because it stores the order before calling downstream and only logs failures; that is why you check the logs, not the status code. With `allow-dns-egress` the resolver works again. In the first seconds after applying the allows you may see `lookup payment-service on 10.96.0.10:53: no such host` in the log: the policy had not been programmed yet (seconds of lag on kindnet).

## Step 9: the dataplane

```text
$ kubectl -n kube-system get cm kube-proxy -o yaml | grep mode
    mode: iptables
$ docker exec desktop-control-plane sh -c "iptables-save -t nat | grep payment-service"
-A KUBE-SERVICES -d 10.96.202.204/32 -p tcp -m comment --comment "orderflow/payment-service:http cluster IP" -m tcp --dport 8081 -j KUBE-SVC-IQ7QSKWRWKVLEXKC
-A KUBE-SVC-IQ7QSKWRWKVLEXKC ! -s 10.244.0.0/16 -d 10.96.202.204/32 ... -j KUBE-MARK-MASQ
-A KUBE-SVC-IQ7QSKWRWKVLEXKC -m comment --comment "orderflow/payment-service:http -> 10.244.0.67:8081" -m statistic --mode random --probability 0.50000000000 -j KUBE-SEP-W4QQRYYOA36IEMGO
-A KUBE-SVC-IQ7QSKWRWKVLEXKC -m comment --comment "orderflow/payment-service:http -> 10.244.0.68:8081" -j KUBE-SEP-5RAII325PYP672FG
-A KUBE-SEP-W4QQRYYOA36IEMGO -p tcp ... -j DNAT --to-destination 10.244.0.67:8081
-A KUBE-SEP-5RAII325PYP672FG -p tcp ... -j DNAT --to-destination 10.244.0.68:8081
-A KUBE-MARK-MASQ -j MARK --set-xmark 0x4000/0x4000
-A KUBE-POSTROUTING -m mark ! --mark 0x4000/0x4000 -j RETURN
-A KUBE-POSTROUTING -j MARK --set-xmark 0x4000/0x0
-A KUBE-POSTROUTING ... -j MASQUERADE --random-fully

$ docker exec desktop-control-plane conntrack -L -d 10.96.202.204
tcp 6 119 TIME_WAIT src=10.244.0.70 dst=10.96.202.204 sport=45994 dport=8081 src=10.244.0.67 dst=10.244.0.70 sport=8081 dport=45994 [ASSURED] mark=0 use=1
$ docker exec desktop-control-plane sysctl net.netfilter.nf_conntrack_tcp_timeout_established
net.netfilter.nf_conntrack_tcp_timeout_established = 86400
```
The chain names are hashes of the Service/port, so yours differ. Read the conntrack line as two tuples: what the client sent (`dst=` ClusterIP) and what comes back (`src=` the real pod). The Envoy proxy Service also appears with `KUBE-EXT-...` chains (LoadBalancer/NodePort path, `externalTrafficPolicy: Local`) and a DNAT to the proxy pod on port `10080` (the Service port 80 maps to the Envoy listener at 10080). The Service object on this cluster reported `externalTrafficPolicy: Local`.

## Step 10: ExternalName

```text
external-demo   ExternalName   <none>   example.com   <none>
external-demo.orderflow.svc.cluster.local	canonical name = example.com
```

## Why it works / what to remember
* **Role split:** `gateway.yaml` is platform-owned (GatewayClass, namespace, Gateway); `httproute.yaml` lives in the app namespace and only attaches (`parentRefs` → `gateway-infra/edge`, allowed by `allowedRoutes.namespaces.from: All`). `reset.sh` deletes `orderflow` and the route with it; the edge survives, which is what Days 6-7 rely on.
* **Envoy talks to pod IPs**, taken from the EndpointSlice; the ClusterIP and kube-proxy DNAT are only used by pod-to-Service traffic such as `order-api → payment-service`. So the earlier diagram "Ingress → ClusterIP → iptables" was wrong for ingress controllers and Gateway implementations alike.
* **Policy is not security until tested:** the same YAML is accepted and ignored on a non-enforcing CNI; always run the deny test.
* **Per-connection balancing:** the `conntrack` entry pins a connection to the chosen pod; long-lived HTTP/2 or keep-alive clients do not rebalance. L7 proxies (Envoy) balance per request.
