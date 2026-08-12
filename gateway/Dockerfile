FROM alpine:3.22@sha256:14358309a308569c32bdc37e2e0e9694be33a9d99e68afb0f5ff33cc1f695dce

RUN apk add --no-cache \
      bash \
      bind-tools \
      iproute2 \
      iptables \
      socat \
      wireguard-go \
      wireguard-tools \
    && adduser -D -H -s /sbin/nologin health

COPY entrypoint.sh reresolve-endpoint.sh /usr/local/sbin/
RUN chmod 0755 /usr/local/sbin/entrypoint.sh /usr/local/sbin/reresolve-endpoint.sh

ENTRYPOINT ["/usr/local/sbin/entrypoint.sh"]
