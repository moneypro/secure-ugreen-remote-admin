FROM alpine:3.22@sha256:14358309a308569c32bdc37e2e0e9694be33a9d99e68afb0f5ff33cc1f695dce

RUN apk add --no-cache autossh openssh-client
COPY entrypoint.sh /usr/local/sbin/entrypoint.sh
RUN chmod 0755 /usr/local/sbin/entrypoint.sh
ENTRYPOINT ["/usr/local/sbin/entrypoint.sh"]
