# Rollback

Rollback does not touch storage pools, volumes, disks, RAID, shares, or NAS data.

## NAS

```bash
sudo docker compose -f deploy/nas-recovery/compose.yml down
sudo docker compose -f deploy/nas-primary/compose.yml down
sudo docker network rm friend-nas-recovery friend-nas-primary 2>/dev/null || true
```

Remove only the public-key lines added for `primary-admin` and `recovery-admin` from
the UGOS administrator's `authorized_keys`, then remove the permission-repair unit:

```bash
sudo systemctl disable --now friend-nas-fix-ssh-permissions.service
```

Do not delete or modify the UGOS account from the shell. Remove it later through the
UGOS UI only if desired.

Retain `/var/backups/friend-nas-remote/` until rollback is verified.

## Seattle

```bash
sudo systemctl disable --now friend-nas-ddns.timer friend-nas-isolation.service
sudo /usr/local/sbin/friend-nas-isolation remove
docker compose --env-file private/site.env -f deploy/home/compose.yml down
sudo rm -f /etc/systemd/system/friend-nas-ddns.{service,timer}
sudo rm -f /etc/systemd/system/friend-nas-isolation.service
sudo rm -f /usr/local/sbin/friend-nas-route53-ddns /usr/local/sbin/friend-nas-isolation
sudo rm -rf /etc/friend-nas-remote
sudo systemctl daemon-reload
```

Remove the router UDP/51830 forward and the dedicated Route 53 record/IAM principal.
Do not modify the existing UDP/51820 WireGuard container or Tailscale.

## AWS

From `aws/terraform` with the same private state and variables:

```bash
terraform plan -destroy -var-file=../../private/recovery.tfvars
terraform destroy -var-file=../../private/recovery.tfvars
```

Confirm the dedicated EIP, instance, IAM role/profile, security group, subnet,
route table, gateway, and VPC were removed. Do not target the existing AI/CAD stack.
