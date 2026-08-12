# Secure remote administration for a UGREEN NAS

Two independent, outbound-established management paths:

- Primary: UGREEN NAS -> WireGuard -> Seattle -> SSH to UGOS
- Recovery: UGREEN NAS -> reverse SSH -> dedicated Hong Kong EC2 -> AWS SSM

The Seattle gateway uses `10.77.0.1`; the NAS uses `10.77.0.10`. Neither path
installs Tailscale on the NAS, forwards into the Seattle LAN, or changes the NAS
default route.

This repository contains no credentials. Generated material and audit output live
under `private/`, which Git ignores.

## Tomorrow: exact order

### 1. Clone on Seattle and on the NAS

```bash
git clone https://github.com/moneypro/secure-ugreen-remote-admin.git
cd secure-ugreen-remote-admin
make check
(cd enrollment/seattle && sha256sum -c SHA256SUMS)
```

### 2. Run audits before changing anything

On Seattle:

```bash
mkdir -p private
./bin/ugreen-remote audit-home | tee private/audit-home.txt
./bin/ugreen-remote audit-aws | tee private/audit-aws.txt
```

On the UGREEN NAS:

```bash
mkdir -p private
sudo ./bin/ugreen-remote audit-nas | tee private/audit-nas.txt
```

Stop here and review UGOS version, SSH persistence, `/dev/net/tun`, WireGuard
kernel/userspace support, Docker restart behavior, interfaces, routes, firewall,
listeners, and existing Docker networks.

### 3. Create the private site inventory

On both systems:

```bash
cp config/site.env.example private/site.env
$EDITOR private/site.env
```

Choose a Route 53 hostname and verify that `10.77.0.0/24`,
`10.250.77.0/29`, `10.250.78.0/29`, and `10.250.79.0/29` do not overlap
either site.

### 4. Generate the NAS-owned credentials

The Seattle public keys are already in `enrollment/seattle/`. Their private halves
exist only in Seattle's ignored `private/keys/` directory.

On the NAS:

```bash
sudo ./bin/ugreen-remote generate-keys nas
sudo ./bin/ugreen-remote generate-keys recovery-tunnel
```

Print the NAS public keys:

```bash
cat private/keys/nas.wg.pub
cat private/keys/recovery-tunnel.pub
```

Paste both public-key lines into the Codex session running on Seattle. They will be
stored as `private/received/nas.wg.pub` and
`private/received/recovery-tunnel.pub`. Never paste or copy the files without the
`.pub` suffix.

### 5. Install the UGOS administrator key

While still on the friend's LAN, install Seattle's committed public key:

```bash
sudo ./nas/install-admin-user.sh \
  --user friend-admin \
  --public-key enrollment/seattle/primary-admin.pub \
  --source 10.250.78.2 \
  --sudo-mode password
sudo passwd friend-admin
```

Record and verify the UGOS SSH host key locally:

```bash
./nas/collect-ssh-host-key.sh NAS_LAN_IP private/known_hosts.ugos
```

Do not disable the working local administration path.

After a second key-only SSH session succeeds, disable SSH passwords:

```bash
sudo ./nas/harden-sshd.sh apply
sudo ./nas/harden-sshd.sh check
```

### 6. Render and start primary WireGuard

The NAS public key goes into Seattle's `private/received/`; copy the committed
Seattle WireGuard public key into the NAS receive directory:

```bash
mkdir -p private/received
cp enrollment/seattle/home.wg.pub private/received/home.wg.pub
```

Then run on each side:

```bash
./bin/ugreen-remote render
```

On Seattle:

```bash
docker compose --env-file private/site.env -f deploy/home/compose.yml config
docker compose --env-file private/site.env -f deploy/home/compose.yml up -d --build
sudo ./home/isolation.sh apply
```

Create a fixed router forward: `UDP 51830 -> 192.168.86.100:51830`.

On the NAS:

```bash
sudo docker compose -f deploy/nas-primary/compose.yml config
sudo docker compose -f deploy/nas-primary/compose.yml up -d --build
```

From Seattle:

```bash
ssh -F private/ssh-config friend-nas
sudo -v
sudo ./home/install-isolation-service.sh
```

### 7. Configure Route 53 DDNS

Create a dedicated IAM credential restricted to the single A record using
`home/route53-policy.json.tmpl`. Store it in the `friend-nas-ddns` AWS profile,
then install the timer:

```bash
sudo ./home/install-ddns.sh private/site.env
systemctl status friend-nas-ddns.timer
```

Change the Route 53 record temporarily to a controlled test address, restore it,
and confirm the NAS endpoint re-resolves without restarting Docker.

### 8. Provision the independent Hong Kong recovery host

On Seattle, after receiving `recovery-tunnel.pub` from the NAS:

```bash
cd aws/terraform
cp recovery.tfvars.example ../../private/recovery.tfvars
$EDITOR ../../private/recovery.tfvars
terraform init
terraform plan -var-file=../../private/recovery.tfvars
terraform apply -var-file=../../private/recovery.tfvars
cd ../..
```

Copy the EC2 EIP and pinned SSH host key into the NAS's private recovery config,
then:

```bash
cp config/recovery.env.example private/recovery.env
$EDITOR private/recovery.env
./aws/get-recovery-host-key.sh INSTANCE_ID ELASTIC_IP > private/recovery-known-hosts
sudo ./nas/install-admin-user.sh \
  --user friend-admin \
  --public-key enrollment/seattle/recovery-admin.pub \
  --source 10.250.79.2 \
  --sudo-mode password
sudo docker compose -f deploy/nas-recovery/compose.yml up -d --build
```

Test recovery from Seattle or a laptop:

```bash
aws ssm start-session \
  --region ap-east-1 \
  --target INSTANCE_ID \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["22010"],"localPortNumber":["22011"]}'

ssh -p 22011 -i private/keys/recovery-admin friend-admin@127.0.0.1
```

### 9. Mandatory on-site tests

Run these in order and record the results:

1. Cellular: disconnect the laptop from the friend's Wi-Fi; SSH through Seattle.
2. Isolation: from the NAS, confirm Seattle LAN, Tailscale addresses, and unrelated
   AWS private addresses are unreachable.
3. Reboot: reboot the NAS; verify both services return without an UGOS login.
4. Home-IP change: exercise Route 53 update and NAS endpoint re-resolution.
5. Primary failure: stop the Seattle gateway; enter through EC2/SSM; restore Seattle.
6. Power-loss model: restart NAS and friend router; verify both paths recover.

Commands and expected results are in [docs/test-plan.md](docs/test-plan.md).

## Day-to-day commands

```bash
# Primary
ssh -F private/ssh-config friend-nas

# Tunnel state
docker exec friend-nas-home-wg wg show wg0
sudo docker exec friend-nas-primary-wg wg show wg0

# Restart
docker compose -f deploy/home/compose.yml restart
sudo docker compose -f deploy/nas-primary/compose.yml restart
sudo docker compose -f deploy/nas-recovery/compose.yml restart
```

See [docs/architecture.md](docs/architecture.md) for trust boundaries and
[docs/operations.md](docs/operations.md) for health/rotation/revocation, and
[docs/rollback.md](docs/rollback.md) for complete removal.
