## Turnkey dockerised setup for running a KDF Seed Node

The included `docker-compose.yml` provides a turnkey setup. It provisions/renews LetsEncrypt certs and runs the mm2 seednode. On every start, `run_mm2.sh` refreshes `coins` file and the `seednodes` field in `MM2.json` from `https://raw.githubusercontent.com/GLEECBTC/coins/master/seed-nodes.json` to keep peers current.

### Step 1 Install Docker and Docker Compose plugin  
### Step 2 Create a `.env` file in the repo root with your settings:

```bash
DOMAIN=your.subdomain.tld
LETSENCRYPT_EMAIL=you@example.com
# Optional: CloudFlare API token for DNS-01 challenge (no port 80 needed)
# Get your token from: https://dash.cloudflare.com/profile/api-tokens
# Create a token with "Edit zone DNS" permissions for your domain
# CLOUDFLARE_API_TOKEN=your_cloudflare_api_token_here
# Optional: predefine RPC password (else generated/loaded)
USERPASS=RPC_UserP@SSW0RD
# Optional: predefine your mm2 passphrase (else generated)
# PASSPHRASE=correct horse battery staple
```

### Step 3 From the repo root, start:

```bash
docker compose up -d --build && docker compose logs -f --tail 5
```


### Step 4: Open the KDF Seednode Ports

```bash
sudo ufw allow 32326
sudo ufw allow 32336
```

**Note about port 80:** If you're using CloudFlare DNS plugin (by setting `CLOUDFLARE_API_TOKEN`), port 80 is not needed and can remain closed. Otherwise, port 80 must be open for Let's Encrypt HTTP validation.

Notes:
- Certificates are created by the `certbot` service and mounted read-only to the `kdf` service.
- **CloudFlare DNS Plugin:** If `CLOUDFLARE_API_TOKEN` is set in `.env`, certbot will use CloudFlare DNS-01 challenge instead of HTTP validation. This means port 80 doesn't need to be open. The token should have "Edit zone DNS" permissions for your domain. Get your token from [CloudFlare API Tokens](https://dash.cloudflare.com/profile/api-tokens).
- **Standalone Mode (default):** If `CLOUDFLARE_API_TOKEN` is not set, certbot uses standalone HTTP challenge on port 80. Ensure TCP/80 is reachable from the internet for issuance and renewals.
- `run_mm2.sh` auto-updates `MM2.json` `seednodes` from the remote list on each start.
- First boot is non-interactive: if `MM2.json` does not exist, it is generated automatically using `USERPASS` and `PASSPHRASE` envs (or securely generated defaults). If `DOMAIN` is set and certificates exist, `wss_certs` is added automatically.
- The `DB/` directory in the repo root is bind-mounted to `/home/komodian/.kdf/DB` inside the container. This is equivalent to setting `"dbdir": "/home/komodian/.kdf/DB"` in `MM2.json` and is the default location KDF uses for its database files. Mounting it explicitly keeps DB files on the host for persistence and easy access.
- Certbot runs continuously inside its container and will attempt automatic renewals every ~12 hours.
- The `coins` file is refreshed automatically on each start from `https://raw.githubusercontent.com/GLEECBTC/coins/refs/heads/master/coins` and saved to `~/.kdf/coins` inside the container.

---

## FAQ

**Q: Which ports does the seed node use?**

| Port  | Protocol | Purpose                        |
|-------|----------|--------------------------------|
| 7783  | TCP      | KDF RPC API (localhost only)   |
| 32326 | TCP      | P2P TCP connections            |
| 32336 | TCP/WSS  | P2P WebSocket Secure (WSS)     |

Ports 32326 and 32336 must be open and reachable from the internet. Port 7783 is bound to localhost only and should not be exposed publicly.

---

**Q: On startup I see repeated `Trying to bind on <public-ip>:<port>` errors followed by `Cannot assign requested address (os error 99)`. Is this normal?**

Yes, this is expected behaviour when running inside a Docker container. Example log:

```
kdf-1  | mm2_net::ip_addr] INFO Trying to fetch the real IP from 'http://checkip.amazonaws.com/' ...
kdf-1  | mm2_net::ip_addr] INFO Trying to bind on x.x.x.x:61797
...
kdf-1  | mm2_net::ip_addr] ERROR IP x.x.x.x not available: Cannot assign requested address (os error 99)
kdf-1  | mm2_net::ip_addr] INFO Trying to bind on 0.0.0.0:61797
```

**Why it happens:** KDF's IP detection logic (`myipaddr`) works as follows:

1. Reads file `myipaddr` in the working directory — uses it if present.
2. Reads field `"myipaddr"` in `MM2.json` — uses it if set.
3. Otherwise runs auto-detection: fetches the public IP from `checkip.amazonaws.com` / `api.ipify.org`, then tries to bind a test `TcpListener` on that IP. Inside a container the public IP is not assigned to any local interface, so the bind fails with `EADDRNOTAVAIL (os error 99)`. KDF then falls back to `0.0.0.0`, which succeeds.

The node operates correctly after the fallback. The failed attempts are harmless.

**How to suppress the warnings:** Set `"myipaddr": "0.0.0.0"` in `MM2.json` to skip auto-detection entirely:

```json
{
  "myipaddr": "0.0.0.0"
}
```

KDF will bind on `0.0.0.0` directly without making any external requests or failed bind attempts.
