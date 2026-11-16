# cloudflare_email_dns

Manages the Strato email records for `base_domain` in Cloudflare:

- `MX 5 smtp.rzone.de` — Strato's active customer inbound gateway. The old
  `mx01.strato.de` / `mx02.strato.de` names are NXDOMAIN.
- `TXT v=spf1 include:_spf.strato.com ~all` — Strato's recommended sender
  include.
- `CNAME strato-dkim-0002._domainkey` and `strato-dkim-0003._domainkey` —
  Strato-managed DKIM selectors, so key rotation stays at Strato.
- `TXT _dmarc v=DMARC1; p=none; pct=100` — start permissive; move to
  `p=quarantine` after live delivery is verified.

The role only touches the root MX records, the first SPF TXT, and the named
DKIM/DMARC records. Other TXT records (domain verifications, etc.) are left
alone.

## Run

Run on the controller with a token that has `Zone:DNS:Edit` for the zone:

```bash
cd ~/tik-work/ansible
CLOUDFLARE_API_TOKEN=... ansible-playbook playbooks/56-email-dns.yml
```

Do not commit the token. The playbook delegates API calls to localhost and is
idempotent.

## Verify

```bash
dig +short MX orangesync.tech
dig +short TXT orangesync.tech
dig +short CNAME strato-dkim-0002._domainkey.orangesync.tech
dig +short CNAME strato-dkim-0003._domainkey.orangesync.tech
dig +short TXT _dmarc.orangesync.tech
```
