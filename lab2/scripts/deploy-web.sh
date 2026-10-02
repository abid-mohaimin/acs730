#!/usr/bin/env bash
# Deploys the ACS730 Lab 2 web app to an EC2 instance and wraps it in systemd.
# Run it from the workstation, from the root of the repo:
#   ./lab2/scripts/deploy-web.sh <instance-public-ip> [path-to-private-key]
# Every step checks what already exists, so running it twice is safe.
set -euo pipefail

HOST="${1:?Usage: $0 <instance-public-ip> [path-to-private-key]}"
KEY="${2:-$HOME/.ssh/acs730-lab2}"
SSH_USER="ec2-user"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIT_FILE="${SCRIPT_DIR}/../acs730-web.service"

if [ ! -f "$KEY" ]; then
  echo "Private key not found at $KEY" >&2
  exit 1
fi
if [ ! -f "$UNIT_FILE" ]; then
  echo "Unit file not found at $UNIT_FILE" >&2
  exit 1
fi

SSH_OPTS=(-i "$KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new)

echo "Copying unit file to ${SSH_USER}@${HOST} ..."
scp "${SSH_OPTS[@]}" "$UNIT_FILE" "${SSH_USER}@${HOST}:/tmp/acs730-web.service"

echo "Running deployment on ${HOST} ..."
ssh "${SSH_OPTS[@]}" "${SSH_USER}@${HOST}" 'sudo bash -s' <<'REMOTE'
set -euo pipefail

APP_USER="acs730web"
APP_DIR="/opt/acs730-web"
UNIT_NAME="acs730-web.service"
PORT=8080

echo "[1/5] Installing packages with dnf"
dnf install -y python3

echo "[2/5] Creating service user ${APP_USER} (if missing)"
if id "$APP_USER" >/dev/null 2>&1; then
  echo "User ${APP_USER} already exists"
else
  useradd --system --no-create-home --home-dir "$APP_DIR" --shell /sbin/nologin "$APP_USER"
fi

echo "[3/5] Deploying site to ${APP_DIR} owned by ${APP_USER}"
install -d -o "$APP_USER" -g "$APP_USER" -m 0755 "$APP_DIR"
TMP_HTML="$(mktemp)"
cat > "$TMP_HTML" <<HTML
<!DOCTYPE html>
<html>
<head><title>ACS730 Lab 2</title></head>
<body>
  <h1>ACS730 Lab 2 web app</h1>
  <p>Served by systemd unit ${UNIT_NAME} as user ${APP_USER}.</p>
  <p>Host: $(hostname)</p>
  <p>Deployed: $(date -u '+%Y-%m-%d %H:%M:%S UTC')</p>
</body>
</html>
HTML
# install sets owner and mode in one step, so the file is never left owned by root.
install -o "$APP_USER" -g "$APP_USER" -m 0644 "$TMP_HTML" "${APP_DIR}/index.html"
rm -f "$TMP_HTML"

echo "[4/5] Installing ${UNIT_NAME}, then enable (survive reboot) and restart (run now)"
install -o root -g root -m 0644 "/tmp/${UNIT_NAME}" "/etc/systemd/system/${UNIT_NAME}"
rm -f "/tmp/${UNIT_NAME}"
systemctl daemon-reload
systemctl enable "$UNIT_NAME"
systemctl restart "$UNIT_NAME"

echo "[5/5] Checking the service"
sleep 2
echo "is-enabled: $(systemctl is-enabled "$UNIT_NAME")"
echo "is-active:  $(systemctl is-active "$UNIT_NAME")"
echo "running as: $(ps -o user= -p "$(systemctl show -p MainPID --value "$UNIT_NAME")")"
curl -fsS "http://localhost:${PORT}/" >/dev/null && echo "HTTP check on port ${PORT}: OK"
REMOTE

echo "Deployment finished. Try: curl http://${HOST}:8080/"
