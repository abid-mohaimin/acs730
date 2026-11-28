# Assignment 1: Multi-Environment Infrastructure Deployment with Terraform

Md Abid Al Mohaimin (maamohaimin), ACS730, Seneca Polytechnic

<!--
HOW TO USE THIS SKELETON
Everything inside these comment blocks is a note to you. Replace each one with
your own prose and then delete the comment. The commands, JSON and file names
outside the comments are real and can stay as they are once you have checked
them against what you actually ran.
-->

## 1. Introduction

<!--
About 5 marks. One or two paragraphs. Say what was built (one Terraform module
called three times, dev/staging/prod, staging auto-deploys on merge, prod waits
for a reviewer), on what (AWS Academy Learner Lab, session-scoped credentials,
GitHub Actions), and what the report covers. Mention the two Academy limits that
shape the design: credentials die with the session, and IAM writes are denied.
-->

## 2. Reusable module (Task 1)

<!--
Explain the module at assignment1/terraform/modules/web-env: what resources it
holds (VPC, public subnets, IGW, route table, security group, EC2 web server,
SSM data source, CloudWatch alarm), which values are inputs and WHY (they differ
between environments: environment, vpc_cidr, public_subnets, instance_type,
cpu_alarm_threshold, db_password_parameter_name), which are locals and why
(identical everywhere: project prefix, tag set), and what it outputs.
Mention the validations: environment name, CIDR, instance size cap, and the
rule that refuses port 22. Justify for_each over count for the subnets.
-->

## 3. Environment directories (Task 2)

| Environment | VPC CIDR | Subnets | Instance type | CPU alarm threshold | State key |
|---|---|---|---|---|---|
| dev | 10.40.0.0/16 | 1 | t3.micro | 90% | assignment1/dev/terraform.tfstate |
| staging | 10.41.0.0/16 | 2 | t3.micro | 80% | assignment1/staging/terraform.tfstate |
| prod | 10.42.0.0/16 | 2 | t3.small | 70% | assignment1/prod/terraform.tfstate |

All three keys live in the single bucket `acs730-tfstate-072374718788`. Evidence: `evidence/backend-state-keys.txt`.

<!--
Explain why one bucket with three keys (not one key, not three buckets), how you
checked the keys before the first apply in each environment, and why dev is
applied from the workstation while staging and prod are applied only by the pipeline.
-->

## 4. GitHub Environments (Task 3)

<!--
Describe staging (no reviewer, deploys as soon as validate passes on main) and
prod (required reviewer abid-mohaimin, deployment branch policy limited to main).
Explain why the job, not the workflow, is what gets gated. Evidence:
evidence/environments.json, evidence/prod-approval-pending.png,
evidence/prod-approval-approved.png.
-->

## 5. Scoped credentials and OIDC trust policy (Task 4)

### 5.1 What was changed

<!--
The three AWS secrets now exist only on the staging and prod environments, the
repository-level copies were deleted, and each deploy job declares environment:.
Evidence: evidence/secrets-scope.txt.
-->

The per-session credential refresh is now:

```bash
./scripts/refresh-gha-creds.sh abid-mohaimin/acs730 staging prod
```

<!--
One or two sentences on why the old two-argument form is now dangerous: it
still exits 0 but writes repository-level secrets that no job can read.
-->

### 5.2 The prod trust policy I would deploy in a real AWS account

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowGitHubActionsProdEnvironmentOnly",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::072374718788:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:abid-mohaimin/acs730:environment:prod"
        }
      }
    }
  ]
}
```

### 5.3 What each part prevents

<!--
The marks are here. Write a short paragraph for EACH of: Principal.Federated,
Action, the aud condition, the sub condition. Then a paragraph comparing the
pinned sub with the loose repo:abid-mohaimin/acs730:* wildcard, and what someone
with push access to any branch could do under the loose version. Talking points
are in the guide.
-->

### 5.4 Why it was not deployed

<!--
One or two sentences: the Learner Lab denies every IAM write
(CreateOpenIDConnectProvider, CreateRole), so session-scoped credentials stored
as environment secrets are the substitute, and their risk is bounded by the
session expiry rather than by a per-job token.
-->

## 6. Real deployment (Task 5)

<!--
Walk through the run: merge to main, validate passed, staging applied with no
human in the loop, prod sat waiting, you approved, prod applied. Name the run
and the commit SHA. Evidence: evidence/staging-apply.txt,
evidence/prod-approval-pending.png, evidence/prod-approval-approved.png,
evidence/prod-apply.txt.
-->

## 7. Secrets management with SSM Parameter Store (Task 6)

Documented pre-step, run once by hand from the workstation before the first plan in each environment (the real value is not recorded here):

```bash
for env in dev staging prod; do
  aws ssm put-parameter \
    --name "/acs730/a1/${env}/db_password" \
    --type SecureString \
    --value "<placeholder-value>" \
    --description "Placeholder DB password for ACS730 Assignment 1 (${env})"
done
```

Terraform reads it with `data "aws_ssm_parameter" "db_password"` in `terraform/modules/web-env/secrets.tf`. Nothing in the Terraform creates the parameter. Evidence: `evidence/ssm-parameter.txt`.

<!--
Explain why the parameter is created outside Terraform (create and read in one
graph is circular, and breaks on a fresh environment), why the value is marked
sensitive, and one honest limitation: a value read by a data source is still
written to the state file, which is why state is encrypted in S3. Say what you
would do in production instead (the instance reads the parameter at boot through
its own IAM role, so the value never enters state).
-->

## 8. CloudWatch alarm (Task 7)

<!--
Which metric (AWS/EC2 CPUUtilization on the web instance), why that metric (it
reports on an idle instance), the threshold per environment, period 300 s x 2
evaluation periods, and the state when captured (OK). Evidence:
evidence/cloudwatch-alarm.json, evidence/cloudwatch-alarm.png.
-->

## 9. Recommendation: GitHub Actions or an AWS-native pipeline?

<!--
One page. Pick ONE and defend it with at least three concrete factors. End with
a clear choice, not "it depends". Talking points are in the guide.
-->

## 10. Teardown (Task 9)

<!--
State that staging, prod and dev were destroyed, how (terraform destroy from
the workstation, output saved), and that cleanup-check.sh reported nothing left.
Evidence: evidence/destroy-complete.txt.
-->

## 11. Conclusion

<!--
About 5 marks, and a conclusion that only summarises earns about half. Add
reflection: what was harder than expected, what you would change with a real
AWS account (OIDC, per-environment roles, the instance reading its own secret),
and what the next layer would be.
-->

## Evidence index

| File | What it shows |
|---|---|
| evidence/backend-state-keys.txt | Three distinct state keys in one bucket |
| evidence/environments.json | staging and prod, prod reviewer and main-only branch policy |
| evidence/secrets-scope.txt | No AWS secrets at repository level, all three on each environment |
| evidence/prod-approval-pending.png | Prod job waiting for review |
| evidence/prod-approval-approved.png | Prod job approved |
| evidence/staging-apply.txt | Automatic staging apply log |
| evidence/prod-apply.txt | Approved prod apply log |
| evidence/ssm-parameter.txt | Parameter metadata and the data source that reads it |
| evidence/cloudwatch-alarm.json | Alarm definition and state |
| evidence/cloudwatch-alarm.png | Alarm in the console, state OK |
| evidence/destroy-complete.txt | Full destroy output for all environments |
