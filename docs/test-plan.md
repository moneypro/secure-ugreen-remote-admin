# On-site acceptance tests

Record timestamps and command output under `private/test-results/`.

## Primary and cellular

```bash
docker exec friend-nas-home-wg wg show wg0
ssh -F private/ssh-config friend-nas 'id; sudo -v; uname -a'
```

Disconnect the laptop from the friend's Wi-Fi and repeat through Seattle.

## Isolation

Use known, non-sensitive targets rather than scanning ranges:

```bash
ip route
ip rule
ping -c 2 SEATTLE_LAN_TARGET       # must fail
ping -c 2 TAILSCALE_TARGET         # must fail
nc -vz -w 3 AWS_PRIVATE_TARGET 22  # must fail
```

Also confirm the WireGuard peer has only `10.77.0.1/32` in `AllowedIPs`.

## Reboot

```bash
sudo reboot
```

After the NAS returns:

```bash
ssh -F private/ssh-config friend-nas
sudo docker inspect -f '{{.State.StartedAt}} {{.RestartCount}}' friend-nas-primary-wg friend-nas-recovery
```

## Seattle address/DDNS

Change the test A record, observe the NAS log an endpoint update, then restore the
correct record. Do not alter the system default route or DNS.

```bash
sudo docker logs --since 10m friend-nas-primary-wg
sudo docker exec friend-nas-primary-wg wg show wg0 endpoints latest-handshakes
```

## Primary failure and recovery

On Seattle:

```bash
docker compose --env-file private/site.env -f deploy/home/compose.yml stop
```

Open the SSM port forward and SSH through local port 22011. Confirm `sudo -v`,
inspect the failed primary, then restore Seattle:

```bash
docker compose --env-file private/site.env -f deploy/home/compose.yml start
```

## Router/power recovery

Reboot the friend router, then power-cycle the NAS. Both paths must recover with
no UGOS login. Check latest WireGuard handshake and recovery-container uptime.

