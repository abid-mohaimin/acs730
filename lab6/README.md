# Lab 6: Ansible Configuration Management and Golden AMIs

## Required answers

**Runner-to-instance mechanism.** I used AWS Systems Manager Session Manager, because the instances open an outbound connection to SSM over 443 using the LabInstanceProfile, so there is no inbound port 22, no runner IP to allow in, and no long-lived private key stored in repository secrets; the GitHub runner authenticates with the same temporary Academy session credentials it already uses for Terraform.

**What changed=0 on a second run proves.** It proves that every task checked the real state of each host and found it already matched what the role asks for, so the playbook is safe to run against a brand new instance and an already converged one with the same command, and safe to run from a pipeline on every merge.

**Why deregistering an AMI is not enough.** An AMI is only a pointer to an EBS snapshot, and the snapshot is the stored data that keeps billing, so deregistering leaves the snapshot behind and, once the AMI is gone, describe-images can no longer tell you which snapshot belonged to it, which is why I read the snapshot id first and deleted it separately.

## How it fits together

Terraform creates two t3.micro instances tagged `Lab=lab6` and `Role=web`, attaches the existing `LabInstanceProfile`, and creates a security group that allows only port 80 in. There is no key pair and no port 22 rule. Ansible never reads a list of addresses. The `amazon.aws.aws_ec2` inventory plugin asks EC2 for running instances tagged `Lab=lab6` at the start of every run, names each host by its instance id, and builds the `role_web` group from the `Role` tag. The `group_vars/role_web.yml` file tells Ansible to reach that group through the `aws_ssm` connection plugin.

One constraint caught my attention in Part 2. The SSM connection plugin does not stream files through the session; it stages them through an S3 bucket I own. The bucket region and `ansible_aws_ssm_region` have to be the same region (us-east-1 here), otherwise the very first task fails with a PermanentRedirect error.

The `webserver` role uses only real modules (`dnf`, `user`, `file`, `template`, `systemd`) with fully qualified names and YAML dict arguments. Packages use `state: present`, the service uses `state: started`, and the only restart lives in a handler that fires when the unit file actually changes. The landing page is rendered from a Jinja2 template using gathered facts, so each host shows its own host name and private IP without any conditional logic, and there is nothing time based in it.

The same role is reused unchanged as the Packer provisioner. Packer overrides `build_tag` to `golden-ami` with `--extra-vars`, which works because the value lives in `defaults/` at the bottom of variable precedence, and then copies the static `files/index.html` to `baked.html`.

## Boot-to-ready comparison

Both numbers were taken with `scripts/boot-to-ready.sh`, starting the clock at the moment AWS was asked for an instance and stopping it at the first HTTP 200.

| Path | Seconds | What the number includes |
|---|---|---|
| Converge on boot (stock AL2023 + Ansible over SSM) | 128 | instance launch, boot, SSM agent registration, dnf package install, templates, service start |
| Golden AMI (Packer) | 21 | instance launch, boot, service start (configuration already baked in) |

In the slow path, very little of the time was the Ansible logic itself. Most of it was waiting for the SSM agent to register after the instance was already running, and then dnf pulling packages over the network. In my run the clock started before `terraform apply -replace`, and Terraform spent about 30 of those 128 seconds terminating the old instance before it launched the new one, so the new instance itself went from launch to a served page in roughly 98 seconds. By the time the apply finished, the SSM agent had already registered, so the ping loop got through on its first try and most of the remaining time went to the six tasks that had real work to do, mainly the package step and the service start. The golden AMI instance answered in 21 seconds, because all of that work had already been done once during the Packer build, which itself took 5 minutes 38 seconds.

A golden AMI moves the cost rather than removing it. The same work still happens, once at build time instead of once per launch, so the AMI wins as soon as more than a couple of instances are launched and loses when only one is needed, because a full Packer build (about eight minutes) is paid to save a couple of minutes. Golden AMIs also have their own weaknesses. An image is frozen at the moment it was baked, so security updates released afterwards are missing until it is rebuilt, which means a rebuild cadence is needed, and nobody can see what is inside an image without reading its build log, whereas a playbook is its own documentation. Converge on boot has the opposite problem: every launch depends on package mirrors being reachable at that exact moment, so a mirror outage produces instances that boot and never become ready, which is the worst possible thing to happen during an autoscaling event at 3 a.m.

**Recommendation.** I would use the golden AMI for the web tier because instances are launched in groups and boot time matters during scaling, and I would switch to converge on boot only if the configuration changed more often than we could afford to rebuild and re-test the image.

## Pipeline

`.github/workflows/lab6-configure.yml` runs only for changes under `lab6/` and only creates infrastructure when it is dispatched manually with `apply=true`. Ansible, the AWS collections, boto3 and the Session Manager plugin are installed before Terraform runs, so the converge step runs immediately after `terraform apply` with nothing in between. A retry loop around `ansible.builtin.ping` waits for the SSM agent to register, because `terraform apply` returns before the agent is online. Because the runner keeps its Terraform state only for the length of the job, a final step destroys what that run created so nothing is left orphaned and billing.

## Experiments

### Experiment 1: breaking idempotency with a shell task

**Prediction.** If I add `ansible.builtin.shell: mkdir -p /opt/acs730-web/logs`, the second run will report changed=1 on each host, because a shell command cannot check the current state and always reports changed. After adding `creates: /opt/acs730-web/logs`, I expect changed=0 on the second run, because Ansible will skip the task once that path exists.

**What I observed.** The prediction held. With the shell task added, both consecutive runs reported `ok=8 changed=1` on both hosts, so the second run was no longer idempotent even though the directory already existed. After adding `creates: /opt/acs730-web/logs` the next run reported `ok=8 changed=0`, because Ansible checked for the path and skipped the command.

**Explanation.** Ansible cannot work this out for itself because a shell command is an opaque string; it has no idea what the command is supposed to make true, so it has no state to compare against unless I tell it with `creates`. After restoring the original tasks file I re-ran the playbook and it reported `ok=7 changed=0` on both hosts again.

### Experiment 2: state: latest versus state: present

**Prediction.** With `state: latest`, the second run a few minutes after the first will most likely still report changed=0, but only because no new python3 or rsync package is likely to be released in that window. The answer does depend on the day: on any day upstream publishes an update, `latest` reports changed and quietly upgrades the package.

**What I observed.** Both runs with `state: latest` reported `ok=7 changed=0` on both hosts, so the prediction held for today: no newer python3 or rsync package had been published since the first converge. That result says nothing about tomorrow, which is exactly the problem.

**Explanation.** In a pipeline that runs on every merge I want `present`, because a merge should only change what the commit changed. With `latest`, the same commit can produce different servers on different days, and an unrelated package upgrade can arrive in the middle of a deploy, so "always up to date" is better handled by rebuilding the image or by a deliberate patch job. I reverted to `present` and re-confirmed `changed=0` on both hosts.
