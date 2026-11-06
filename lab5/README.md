# ACS730 Lab 5: Terraform Introduction and Reliable CI

## What I built

In lab5/ I wrote one Terraform configuration that can point at real AWS or at LocalStack, and a single variable, `use_localstack`, decides which. The network is a VPC (10.42.0.0/16), two public subnets built with `for_each` from the `public_subnets` map, an internet gateway, a public route table with a 0.0.0.0/0 route through that gateway, one route table association per subnet, and a security group whose ingress rules come from a `dynamic "ingress"` block. On top of the network there is one t3.micro web server whose `user_data` installs nginx, and an optional S3 bucket that is switched on or off with `count`.

Everything is wired by attribute reference, for example `vpc_id = aws_vpc.main.id`, so Terraform builds the dependency graph from the references. The `aws_region` and `aws_availability_zones` data sources, plus the `aws_ami` lookup used against real AWS, mean that no VPC, subnet, security group or AMI id is typed in by hand. The files are versions.tf, providers.tf, variables.tf, network.tf, compute.tf, outputs.tf and localstack.tfvars. Every variable has a type and a description, and `project`, `vpc_cidr` and `instance_type` have validation blocks.

Against LocalStack on my workstation the plan said "10 to add, 0 to change, 0 to destroy", and the apply finished with "Apply complete! Resources: 10 added", with `provider_target` reporting `localstack (http://localhost:4566)`. After `terraform destroy`, evidence/describe-vpcs-after-destroy.json only shows LocalStack's own default 172.31.0.0/16 VPC, so my 10.42.0.0/16 VPC was really gone.

The CI is in .github/workflows/lab5-ci.yml. The cheap job, `fmt and validate`, runs first, and `plan and apply against LocalStack` only runs if it passes, because of `needs: gates`. LocalStack runs as a service container on the runner, and the workflow holds no AWS credentials and no secrets. The credential grep from Part 9 found nothing and exited with code 1. Both jobs are required status checks on main.

Two things did not go exactly like the handout. First, the handout's provider block uses `skip_requester_charged`, but that argument does not exist in the AWS provider 5.x. I checked the provider source on its release/5.x branch, and the only skip settings are `skip_credentials_validation`, `skip_metadata_api_check`, `skip_region_validation` and `skip_requesting_account_id`. I used `skip_requesting_account_id`, so validate passes. Second, my workstation is a t3.micro with about 1 GB of memory and no swap, and the first plan with LocalStack running froze the machine so badly that I had to reboot it. Adding a 1.5 GB swap file fixed it, and the next plan only used about 32 MB of swap.

## Why for_each here and count there

The subnets use `for_each` because each subnet is a distinct thing with a stable name, `a` and `b`. With `for_each` the map key becomes part of the resource address, `aws_subnet.public["a"]`, and addresses are what Terraform compares between runs. Adding a key `c` to `public_subnets` would plan as 1 to add, 0 to change, 0 to destroy, and removing `a` would plan as 1 to destroy while `b` is left alone, because the address of `b` never changes. The route table association is also `for_each` over `aws_subnet.public`, so each association follows its subnet's key instead of a position.

If the same subnets were built with `count`, the addresses would be `public[0]`, `public[1]` and `public[2]`. Deleting the middle entry shifts everything after it down one slot, so Terraform compares `public[1]` in state with what is now a different subnet in the configuration and plans to destroy and recreate two subnets just to remove one.

The artifact bucket uses `count` because the input is a yes or no question about one resource. There are only two possible plans, 0 to add or 1 to add, and there is no key that needs to stay stable. I saw this in Experiment 4, where turning `create_artifact_bucket` off destroyed exactly that one bucket and nothing else. In short, `count` answers "how many" and `for_each` answers "which ones".

## Why not plan and apply against real AWS on every pull request

The first problem is money. The Academy gives me a fixed $50 for the whole term, and a real plan and apply on every pull request builds and destroys real infrastructure each time, including an EC2 instance. This one pull request alone ran the pipeline three times (green, then my deliberate red, then green again), and every push to it would have been another real build. LocalStack cost nothing for any of those runs and left nothing behind.

The second problem is credentials. To apply from GitHub Actions against real AWS, the workflow needs an AWS credential, which means keys stored in GitHub secrets that can leak and have to be rotated. The normal fix is OIDC with a narrow role, but in an Academy account every IAM write is denied, so I cannot create an OIDC provider or a scoped role. The only credentials that work are the broad LabRole session keys, which is the worst kind of key to hand to every pull request.

The third problem is that Academy sessions expire after a few hours. A pull request opened in the evening would fail the next morning with an expired token for a reason that has nothing to do with the code, and people quickly learn to ignore red checks. A check that people ignore is worse than having no check.

The fourth problem is speed and flakiness. Against LocalStack the whole LocalStack job took about 1 minute 50 seconds, and when I broke the code on purpose the failed run stopped after 23 seconds because the gate job caught it before any container was pulled. Real AWS would take minutes for every apply and destroy, it can hit API rate limits and eventual consistency errors, and two pull requests running at the same time would collide on names in one account, for example the security group name and the globally unique bucket name.

I also have to be honest about the limit of LocalStack. A green LocalStack run proves that the configuration is coherent and that the graph builds. It does not prove that IAM permissions are right, because LocalStack does not enforce IAM, and it does not prove that `user_data` works, because LocalStack never boots the instance. The `web_public_ip` it gave me, 54.214.224.38, was invented and does not route anywhere. So the real AWS check belongs on merge to main or on a schedule, run once, and not on every pull request.

## Experiments

### Experiment 2: delete the depends_on

I predicted that commenting out `depends_on = [aws_route_table_association.public]` in compute.tf would give "No changes". The plan against LocalStack, with the resources already built, said "No changes. Your infrastructure matches the configuration." (evidence/exp2-no-depends-on-plan.txt). This happens because `depends_on` only changes the order Terraform creates things in, and it is not an attribute of the instance, so nothing about the existing resources is different. The danger only shows on a fresh build in real AWS: without it, Terraform is free to launch the instance before the route table association exists, `user_data` runs once at first boot with no default route, `dnf install nginx` hangs, and the server comes up with no web page and no error. LocalStack hides this bug completely because it never boots the instance or runs `user_data`.

### Experiment 4: turn the bucket off

I predicted that with `create_artifact_bucket = false`, `terraform output artifact_bucket` would print null. The apply destroyed the bucket, but the output command gave `Error: Output "artifact_bucket" not found` with exit code 1, and the full `terraform output` list left it out completely (evidence/exp4-bucket-off-outputs.txt). So my prediction was only half right. `one()` really does return null when the list is empty, but Terraform does not store outputs whose value is null in the state file, so asking for it by name looks like the output does not exist.

Then I changed `one(aws_s3_bucket.artifacts[*].bucket)` to `aws_s3_bucket.artifacts[0].bucket` and predicted an error. The plan failed with "Invalid index ... aws_s3_bucket.artifacts is empty tuple" (evidence/exp4-index-error.txt), because with count = 0 the resource is a list with zero items and there is no item 0. It failed at plan time, before anything was built. This is why `one()` with `[*]` is the right idiom for a count-gated resource: it turns zero or one item into null or the value without an index error. I restored outputs.tf after the experiment.

## Evidence

| File | What it shows |
|---|---|
| evidence/pr-checks-green.txt, evidence/ci-runs-green.txt | The first green run of both lab5-ci jobs on pull request #7 |
| evidence/required-check-blocked.png | The deliberate break: `fmt and validate` failing and Required, the LocalStack job skipped, and the merge button disabled |
| evidence/pr-blocked.json | GitHub's own status for the pull request during the break: `"mergeStateStatus":"BLOCKED"` |
| evidence/ci-runs.txt | lab5-ci run history: success, then the deliberate failure, then success after the fix |
| evidence/describe-vpcs-after-destroy.json | LocalStack after `terraform destroy`: only the default 172.31.0.0/16 VPC, no 10.42.0.0/16 |
| evidence/exp2-no-depends-on-plan.txt | Experiment 2 plan output |
| evidence/exp4-bucket-off-outputs.txt, evidence/exp4-index-error.txt | Experiment 4 outputs and the index error |

## How to run it

From lab5/ on the workstation, with LocalStack running:

    docker run -d --name localstack -p 4566:4566 -e SERVICES=ec2,s3,sts,iam localstack/localstack:3.8
    terraform init
    terraform plan -var-file=localstack.tfvars -out=tfplan
    terraform apply -auto-approve tfplan
    terraform output
    terraform destroy -auto-approve -var-file=localstack.tfvars
    docker rm -f localstack

Always check that `provider_target` says localstack before applying. Without `-var-file=localstack.tfvars`, `use_localstack` defaults to false and the plan targets real AWS.
