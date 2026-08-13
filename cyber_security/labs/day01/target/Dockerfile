# Day 1 recon target: a stock nginx server (deliberately left at default
# config, so it leaks its version banner) plus a second, deliberately
# leaky "legacy" TCP service on 2121 that announces an outdated
# software name and version the moment a connection opens.
#
# Nothing here is exploitable beyond information disclosure — this target
# exists purely to be *recon'd*, not compromised. That's the point of Day 1.
FROM nginx:1.21-alpine

# busybox-extras provides the `nc` build with -l/-p (listen mode) used by
# entrypoint.sh for the leaky legacy-service banner on port 2121.
RUN apk add --no-cache busybox-extras

COPY index.html /usr/share/nginx/html/index.html
COPY banner.txt /banner.txt
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80 2121

ENTRYPOINT ["/entrypoint.sh"]
