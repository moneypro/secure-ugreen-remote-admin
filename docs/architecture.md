# Architecture

## Primary

```text
Seattle SSH client + primary-admin key
  -> 127.0.0.1:22010
  -> isolated home WireGuard container (10.77.0.1)
  -> outbound-maintained WireGuard session
  -> isolated NAS WireGuard container (10.77.0.10)
  -> UGOS host TCP/22
```

The WireGuard containers do not hold an administrator SSH private key. SSH is
end-to-end and the UGOS Ed25519 host key is pinned. The NAS peer is allowed only
`10.77.0.1/32`; Seattle allows only `10.77.0.10/32`.

Seattle's host firewall permits only established traffic from `br-friendwg` and
drops new container-originated traffic. The container has no forwarding rules.
It cannot route into `192.168.86.0/24`, `tailscale0`, or other Docker networks.

## Recovery

```text
UGOS TCP/22 <- NAS recovery container <- restricted reverse SSH -> EC2 loopback:22010
                                                                  ^
                                                            AWS SSM port forward
```

The EC2 tunnel principal can create one loopback reverse listener and has no shell,
PTY, agent forwarding, local forwarding, or gateway bind. EC2 does not store a NAS
administrator key. A separate recovery administrator key authenticates end-to-end
to UGOS.

## Credentials

| Credential | Private-key location | Authorization |
|---|---|---|
| Home WireGuard | Seattle gateway config | NAS peer only |
| NAS WireGuard | NAS gateway config | Seattle `/32` only |
| Primary admin SSH | Seattle only | `friend-admin`, full sudo |
| Recovery tunnel SSH | NAS recovery container | EC2 reverse listener only |
| Recovery admin SSH | Seattle/laptop | `friend-admin`, full sudo |
| Route 53 IAM | Seattle only | One A record |

## Startup

- Both WireGuard containers: Docker `restart: unless-stopped`.
- NAS endpoint DNS: re-resolved inside the primary container every 60 seconds.
- Recovery SSH: `autossh`, SSH keepalives, Docker restart policy.
- Route 53 DDNS: systemd timer every two minutes.
- Seattle bridge isolation: systemd oneshot after Docker.

No component modifies the NAS default route or global DNS.

