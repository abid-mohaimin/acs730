# Lab 2: Deploying a Web App to EC2 with systemd

`systemctl start` runs the service right now for the current boot only, while `systemctl enable` links the unit into `multi-user.target` so systemd starts it automatically on every future boot, which is why the service needs both.

## scripts/deploy-web.sh
Runs from my workstation. It copies the unit file to the instance over SSH, installs Python with dnf, creates the `acs730web` service user, writes the site to `/opt/acs730-web` owned by that user, then enables and restarts the service. Every step checks what already exists, so it can be run again safely.

## acs730-web.service
The systemd unit. It serves `/opt/acs730-web` on port 8080 with Python's built-in web server, running as `acs730web` instead of root.

## evidence/
The security group rules, the service running before the reboot, and the service running after the reboot.
