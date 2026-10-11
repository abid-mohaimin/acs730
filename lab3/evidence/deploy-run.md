# Lab 3 evidence: automatic terraform apply after merge to main

- Pull request: https://github.com/abid-mohaimin/acs730/pull/3
- Deploy run (push to main, apply ran): https://github.com/abid-mohaimin/acs730/actions/runs/38107401346
- Result: `Apply complete! Resources: 0 added, 1 changed, 0 destroyed.`
- The run modified the existing security group sg-0a9d0c93183a78349 (created from the workstation) instead of creating a new one, so CI and the workstation share one state file.
