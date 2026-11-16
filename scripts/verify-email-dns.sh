#!/usr/bin/env bash
# Verify the Strato email DNS records for orangesync.tech.
#
# Uses Cloudflare DNS-over-HTTPS so a local recursive resolver's negative cache
# cannot hide a freshly created DMARC or SPF record.
#
# Usage: scripts/verify-email-dns.sh [domain]
set -euo pipefail

domain="${1:-orangesync.tech}"
fail=0

resolve() {
  local name="$1" type="$2"
  curl -fsS -H 'accept: application/dns-json' \
    "https://cloudflare-dns.com/dns-query?name=${name}&type=${type}" \
    | python3 -c 'import sys,json; d=json.load(sys.stdin); print("\n".join(a.get("data","") for a in d.get("Answer",[])))'
}

check() {
  local label="$1" haystack="$2" needle="$3"
  if grep -Fq -- "$needle" <<<"$haystack"; then
    printf 'OK   %s\n' "$label"
  else
    printf 'FAIL %s (expected %s)\n' "$label" "$needle"
    fail=1
  fi
}

check_absent() {
  local label="$1" haystack="$2" needle="$3"
  if grep -Fq -- "$needle" <<<"$haystack"; then
    printf 'FAIL %s (unexpected %s)\n' "$label" "$needle"
    fail=1
  else
    printf 'OK   %s\n' "$label"
  fi
}

mx="$(resolve "$domain" MX || true)"
check "MX points at smtp.rzone.de" "$mx" "5 smtp.rzone.de."
check_absent "old mx01/02 removed (mx01)" "$mx" "mx01.strato.de"
check_absent "old mx01/02 removed (mx02)" "$mx" "mx02.strato.de"

spf="$(resolve "$domain" TXT | grep -i 'v=spf1' || true)"
check "SPF authorises Strato" "$spf" "include:_spf.strato.com"
check_absent "old include:strato.de removed" "$spf" "include:strato.de"

dkim2="$(resolve "strato-dkim-0002._domainkey.$domain" CNAME || true)"
dkim3="$(resolve "strato-dkim-0003._domainkey.$domain" CNAME || true)"
check "DKIM selector 0002" "$dkim2" "strato-dkim-0002._domainkey.rzone.de."
check "DKIM selector 0003" "$dkim3" "strato-dkim-0003._domainkey.rzone.de."

dmarc="$(resolve "_dmarc.$domain" TXT || true)"
check "DMARC record present" "$dmarc" "v=DMARC1"

exit "$fail"
