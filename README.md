# Headless Orca server

Docker Compose stack that runs `orca serve` so you can pair the Orca desktop app on this Mac with a containerized runtime. The image also installs the [pi](https://pi.dev) coding agent and the `pi-profile` extension.

## Start

```bash
cp .env.example .env   # optional; defaults pair via localhost:6768
docker compose build
docker compose up -d
docker compose logs -f orca-server
```

Wait for `Orca server ready` and a `Pairing URL: orca://pair?code=...` line.

## Pair with local Orca

1. Copy the pairing URL from the logs.
2. In Orca desktop: **Settings → Remote Orca Servers → Add Server**, paste the link.
3. Or from a CLI: `orca environment add --name docker --pairing-code 'orca://pair?code=...'`.

`ORCA_PAIRING_ADDRESS=127.0.0.1` is correct when the client is this Mac and port `6768` is published. For another machine, set it to a reachable LAN or Tailscale address (not `127.0.0.1`) and redeploy.

The pairing link is a credential. Paired devices live in the `orca-home` volume and survive rebuilds.

## Agents

Pi is on `PATH` inside the container (`pi --version`, `pi list`). Auth and extra CLIs belong on the server, not your laptop.

### OpenRouter

Put your key in `.env` (see `.env.example`):

```bash
export OPENROUTER_API_KEY=sk-or-v1-...
```

Compose injects that variable. The entrypoint also writes it to `~/.pi/agent/auth.json` (same store as `/login openrouter`). Check it:

```bash
docker compose run --rm orca-server pi auth check --provider openrouter
```

```bash
docker compose exec orca-server pi list
docker compose exec -it orca-server bash
```

Install other agents from an Orca terminal on this server (they persist under `/home/orca/.local`).

## Git / private GitHub repos

`git` is on `PATH`. Clone into `~/Development` (persists on the `orca-home` volume):

```bash
cd ~/Development
git clone https://github.com/SquidCorp/some-private-repo.git
```

Set `GITHUB_TOKEN` in `.env` (local) or Coolify **Environment Variables** (VPS). Use a classic PAT or fine-grained token with `contents:read` (and `contents:write` if you push). SSH `git@github.com:...` URLs are rewritten to HTTPS so the same token works.

```bash
docker compose exec orca-server git -C /home/orca/Development ls
```

## Upgrade

Bump `ORCA_VERSION` in `.env` and run `docker compose build --no-cache && docker compose up -d`.
