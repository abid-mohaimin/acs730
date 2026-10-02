# Lab 2: Deploying a Web App to EC2 with systemd

## Deployment steps
From my Week 1 workstation I created my own key pair (`acs730-lab2-key`), a security group (`acs730-lab2-sg`) and an Amazon Linux 2023 t3.micro instance (`acs730-lab2-web`). On the instance I created my own admin user, `acs730admin`, in the `wheel` group, and did the rest of the work as that user. I copied `lab2/` to the instance and ran `scripts/deploy-web.sh`, which does these steps in order:

1. Installs `python3` with dnf.
2. Creates the no-login service user `acs730web`, only if it does not exist yet, so the script is safe to run twice.
3. Creates `/opt/acs730-web`, writes `index.html` and gives the whole folder to `acs730web` with `chown -R`.
4. Copies `acs730-web.service` into `/etc/systemd/system/` and runs `systemctl daemon-reload`.
5. Runs `systemctl enable` and `systemctl restart`, then checks the page on localhost.

## systemctl start vs enable
`systemctl start` runs the service right now but only until the next reboot, while `systemctl enable` links it into `multi-user.target` so systemd starts it automatically at every boot, which is why the script does both.

## Why SSH is a /32 but HTTP is 0.0.0.0/0
SSH is administrative access, so port 22 is open only to my workstation (`32.198.27.78/32`). HTTP is the service the public is supposed to reach, so port 80 is open to `0.0.0.0/0`. Least privilege does not mean closing everything; it means each port is open to exactly the audience that needs it. A few minutes after port 80 was opened, the service log already showed requests from an unknown internet scanner, which shows how quickly exposed ports get found.

## Which user runs the application
The application runs as `acs730web`, a system account with no password and `/sbin/nologin` as its shell. If someone found a bug in `http.server`, they would only get that user's rights instead of root's. Ports below 1024 normally need root, so the unit grants the single capability `CAP_NET_BIND_SERVICE` instead of running the app as root.

## Note on sudo
The handout says `wheel` has passwordless sudo on AL2023, but on my instance sudo asked `acs730admin` for a password it does not have. As `ec2-user` I added `%wheel ALL=(ALL) NOPASSWD: ALL` in `/etc/sudoers.d/90-wheel-nopasswd`, checked it with `visudo -c`, and then switched to `acs730admin`.

## Evidence
- `security-group-rules.json`: exactly two ingress rules, tcp/22 from my /32 and tcp/80 from 0.0.0.0/0.
- `service-before-reboot.txt`: active and enabled, running since 03:24:04 UTC (PID 3209).
- `service-after-reboot.txt`: enabled and running since 03:30:32 UTC (new PID 1873) after a reboot, with nobody starting it.
- `http-after-reboot.txt`: `HTTP/1.0 200 OK` from the workstation after the reboot.

## Experiments

### 1. start without enable
Prediction: I expected the site to still work right after disabling it, but to be down after a reboot. Result: after `sudo systemctl disable acs730-web` the site still returned 200 because the process was already running. After the reboot, curl failed with "Could not connect to server" and `systemctl status` showed `disabled` and `inactive (dead)`, because the link in `multi-user.target.wants` was gone. I fixed it with `sudo systemctl enable --now acs730-web` and the site returned 200 again.

### 2. Drop the capability
Prediction: I expected a permission error when Python tried to use port 80 as a normal user. Result: with the `AmbientCapabilities` line commented out, `journalctl -u acs730-web` showed `PermissionError: [Errno 13] Permission denied` from `socket.bind`, systemd kept retrying (`activating`), and curl got no answer. This explains why web servers historically started as root: binding a port below 1024 needed root, so they started as root and dropped privileges later. The capability gives the process only that one privilege, and after restoring the line the site returned 200.
