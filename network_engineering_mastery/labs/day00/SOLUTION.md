# Day 0 solution — two faults, two kinds of evidence

Read this after you have written your own chain in `journal.md`. Run everything inside
`netlab`, from `/course`.

The symptom bundles two independent faults. Fault A hides the laptop from the network,
and fault B hides the whole home from the Internet. They leave different marks, so you
separate them by where you capture.

## Fault A: the laptop's DHCP server is gone (link-local address)

1. `ip -n lap -4 addr` shows `inet 169.254.x.y/16` instead of an address in
   `192.168.1.0/24`. Addresses in 169.254.0.0/16 are never handed out by a server: the
   host assigned itself one after nobody answered DHCP (IPv4 link-local, "APIPA").
   `ip -n lap route` shows a `169.254.0.0/16` route and no default via `192.168.1.1`.
2. Capture while the laptop asks again:

   ```bash
   ip netns exec lap tcpdump -vni eth0 'udp port 67 or udp port 68'
   ip netns exec lap timeout 15 dhcpcd -4 -1 -B --nobackground -f /dev/null -o domain_name_servers -t 10 eth0
   ```

   You see `Request` lines (Discover) from `0.0.0.0.68` to `255.255.255.255.67`, repeated
   with growing gaps, and no `Reply` (Offer). The laptop spoke and nobody answered.
3. The laptop also lost DNS: `cat /etc/netns/lap/resolv.conf` has no `nameserver` line,
   because the failed run rewrote it and no server supplied option 6. The renewal below
   restores it.
4. Look at the other end. `ip netns pids hr` prints nothing, and
   `ip netns exec hr ss -ulpn` shows no listener on UDP 67 (and none on 53). The
   `dnsmasq` in the home router is gone. The laptop is fine, the cable is fine (the
   Discovers leave `eth0`), and the server is dead.

**Fix:** restart the server, drop the self-assigned address, ask again.

```bash
ip netns exec hr setsid dnsmasq --no-daemon --conf-file=/dev/null --interface=lan0 --bind-interfaces \
  --dhcp-range=192.168.1.100,192.168.1.150,12h \
  --dhcp-option=option:router,192.168.1.1 --dhcp-option=option:dns-server,192.168.1.1 \
  --dhcp-leasefile=/run/netlab/leases --pid-file=/run/netlab/dnsmasq.pid --log-dhcp \
  --address=/www.example.test/203.0.113.10 --port=53 >/run/netlab/dhcp.log 2>&1 </dev/null &
ip -n lap addr flush dev eth0
rm -rf /var/lib/dhcpcd/*
ip netns exec lap timeout 15 dhcpcd -4 -1 -L -B --nobackground -f /dev/null -o domain_name_servers eth0
```

The `rm` matters: a stored lease makes dhcpcd try to rebind the old address first, which
wastes time. `-L` stops it racing into a 169.254 address, so the retry gets a real lease
or fails. On a real host the same "forget the lease" step is `dhcpcd -k` (release) and
deleting the lease files.

Partial fix: restarting the server alone changes nothing for the laptop. It keeps the
169.254 address until it asks again, which is why the flush and the new request are part
of the fix. After A is fixed and B is not, checks 1 to 3 pass, check 4 (the web request)
still fails.

## Fault B: the ISP lost its CGNAT rule (private source on the Internet)

Fix A first so the laptop can send. Then:

1. From the laptop the request to `www.example.test:8080` hangs, and so does
   `ip netns exec hr curl -sS --max-time 5 http://203.0.113.10:8080/` from the home
   router itself. The laptop is not the problem and DNS is fine. The break is further
   out.
2. Capture on each hop, farthest first. On `transit`, the ISP side:
   `ip netns exec transit tcpdump -ni down0 tcp port 8080` shows the SYN with source
   `100.64.0.2` (the home router's WAN address), retransmitted at about 1 s and 2 s:

   ```
   IP 100.64.0.2.38228 > 203.0.113.10.8080: Flags [S], ...
   ```

   On the server side, `ip netns exec transit tcpdump -ni srv0 tcp port 8080` shows the
   SYN forwarded and the server answering:

   ```
   IP 100.64.0.2.38228 > 203.0.113.10.8080: Flags [S], ...
   IP 203.0.113.10.8080 > 100.64.0.2.38228: Flags [S.], ...
   ```

   The request gets there. The reply is the packet that dies, at transit, because its
   destination is `100.64.0.2` (the port number differs per run).
3. `ip -n transit route get 100.64.0.2` prints `RTNETLINK answers: Network is
   unreachable`. Transit has no route to `100.64.0.0/10` and no default, and the Internet
   does not carry that range: shared and private space is reused by every home and every
   ISP. Transit cannot send the SYN-ACK anywhere, so none comes back.
4. Why did it work before? `ip netns exec isp nft list ruleset` is now empty. Healthy,
   it holds `ip saddr 100.64.0.0/10 oifname "up0" masquerade` in a `nat postrouting`
   chain, so the ISP presented the packet as `198.51.100.1`, an address transit can route
   back to. The home router's own NAT still works (the `wan0` capture shows
   `100.64.0.2`), so the fault is exactly one hop out.

**Fix:**

```bash
ip netns exec isp nft add rule ip nat postrouting ip saddr 100.64.0.0/10 oifname up0 masquerade
```

Partial fix: fixing B alone leaves the laptop without an address, so every laptop-side
check still fails. Fixing A alone lets the laptop send, and the request still dies at
transit. Both fixes are needed.

## Verify once per fix

```bash
bash labs/day00/verify.sh
```

| After fixing | Expected failing checks |
|---|---|
| nothing | all five |
| A only (server and lease) | the fetch and the "srv saw 198.51.100.1" check |
| B only | all five (the laptop still has no lease) |
| A and B | none, PASS |
