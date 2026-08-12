# Operations

## Locations

| Component | Location |
|---|---|
| Local inventory | `private/site.env` |
| Local keys | `private/keys/` |
| Peer public keys | `private/received/` |
| Rendered WireGuard | `private/rendered/` |
| Seattle SSH alias | `private/ssh-config` |
| Seattle isolation backups | `/var/lib/friend-nas-remote/backups/` |
| NAS account backups | `/var/backups/friend-nas-remote/` |
| Seattle DDNS config | `/etc/friend-nas-remote/site.env` |

## Health

```bash
docker exec friend-nas-home-wg wg show wg0
sudo docker exec friend-nas-primary-wg wg show wg0
sudo docker logs --since 15m friend-nas-primary-wg
sudo docker logs --since 15m friend-nas-recovery
systemctl status friend-nas-ddns.timer friend-nas-isolation.service
```

For WireGuard, check `latest handshake`, endpoint, and transfer counters. Logs contain
endpoint IPs and state changes, never private keys.

## Restart

```bash
docker compose --env-file private/site.env -f deploy/home/compose.yml restart
sudo docker compose -f deploy/nas-primary/compose.yml restart
sudo docker compose -f deploy/nas-recovery/compose.yml restart
sudo systemctl restart friend-nas-ddns.service
```

## Rotate primary WireGuard

Generate a new peer key into a temporary private directory. Enroll the new public
key on Seattle first, replace the NAS key/config second, confirm a handshake, then
remove the old Seattle peer. Never replace both sides simultaneously without the
recovery path working.

## Rotate administrator SSH

Generate a new key, append its public key to UGOS, verify a new session and sudo,
then remove the old authorized-key line. Primary and recovery keys remain distinct.

## Revoke the NAS

1. Remove the NAS peer from Seattle WireGuard and restart the gateway.
2. Remove both NAS administrator public-key lines from UGOS.
3. Remove the `nas-tunnel` authorized key or destroy the dedicated EC2 stack.
4. Remove the Route 53 record and router port forward if no longer used.
5. Preserve logs and backups until revocation is verified.

