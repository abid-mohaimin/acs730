# ACS730 Lab 4

## Image size: naive vs slim

| Image | Base image | Size | Rebuild time after a one-line code change |
|---|---|---|---|
| acs730-lab4:naive | python:latest (1.13GB) | 1.15GB | 5.313 s |
| acs730-lab4:slim | python:3.12-slim-bookworm (124MB) | 130MB | 0.635 s |

**How much of the difference is the base image.** The two images differ by about 1.02GB and the two base images alone differ by about 1.0GB, so roughly 99% of the gap comes from choosing python:latest, which ships a full Debian with build tools, over the slim tag; most of the rest is the pip install layer, which is 17.8MB in the naive image against 6.38MB in the slim one because the slim Dockerfile uses --no-cache-dir.

**Whether the dependency layer is CACHED on a code-only rebuild.** In the slim image the pip install layer showed CACHED after a one-word edit to app.py and the rebuild took 0.635 s, while in the naive image pip install ran again (4.7 s of a 5.313 s rebuild) because COPY . . comes before RUN pip install, so any code change invalidates the install layer.

**What .dockerignore kept out of the context.** The build context went from 831B for the naive build without a .dockerignore to 473B for the slim build, because .dockerignore kept README.md, the evidence folder and the Dockerfiles out; .git never appeared in either build because the context is lab4/ and .git lives at the repository root.


## CI timings: baseline, cache miss, cache hit

Times are job durations taken from `gh run view <id> --json jobs`. Run IDs: baseline 40155005921, cache miss 40155726930, cache hit 40155911978. The hit run's log shows "Cache restored from key" for the pip cache in both matrix cells, and the build job shows "importing cache manifest from gha" with every layer marked CACHED.

| What | Baseline | Cache miss | Cache hit | Worth it? |
|---|---|---|---|---|
| pip install (test 3.12 job) | 7 s | 9 s | 10 s | No |
| docker build (build job) | 20 s | 30 s | 35 s | No |
| Whole workflow (wall clock) | 58 s | 63 s | 71 s | |

**pip cache verdict.** Not worth it for this lab, because the app only installs flask, gunicorn and pytest, which download in a second or two, so restoring and checking the cache took about as long as downloading the packages fresh.

**Docker layer cache verdict.** Not worth it here either, because even though the hit run restored every layer as CACHED, setting up buildx and importing and exporting the cache through GitHub's cache service added more time than skipping a 5 second pip install saved; it would pay off for a bigger image with a slow dependency install.

## Composite action vs reusable workflow

The dependency setup is an action because it is only a few steps (setup-python with the pip cache, then pip install) that have to run on the same runner as the tests that need those packages, so it drops straight into the existing test job. The image build is a reusable workflow because it is a whole job with its own runner that needs packages: write, a permission the test job must never have, and it hands the finished image-ref back to the caller as an output.

## How to build, run and reach /healthz

From inside lab4/ on the workstation:

    docker build -t acs730-lab4:slim .
    docker run -d --name lab4 -p 8000:8000 acs730-lab4:slim
    curl -s http://localhost:8000/healthz
    docker exec lab4 whoami
    docker rm -f lab4

The health check returns {"status":"ok","version":"dev"} and whoami prints appuser. Tests run with python3 -m pytest from inside lab4/ after installing requirements.txt and requirements-dev.txt.

## Why the image goes to GHCR tagged by commit SHA

Every push to main publishes ghcr.io/abid-mohaimin/acs730-lab4:sha-<first 12 characters of the commit>, for example sha-9d67d2285a27. A SHA tag points at exactly one commit forever, so I can always tell which code is inside a running image and roll back by pulling an older tag, while latest gets overwritten by whatever was pushed last and stops answering that question. GHCR also fits this lab because the workflow logs in with the GITHUB_TOKEN that Actions creates for every run, so no registry password or cloud credential is stored anywhere. The workflow default is contents: read, and only the jobs that push to GHCR widen it to packages: write, restating contents: read because a job-level permissions block replaces the default instead of adding to it.

## GitHub Actions vs AWS-native: my recommendation

The AWS-native version of this pipeline would be CodePipeline for the job graph, CodeBuild for the runners and ECR instead of GHCR. With GitHub Actions the runner lives in GitHub's infrastructure and gets a short-lived GITHUB_TOKEN automatically, which is enough to push to GHCR, but pushing to ECR from Actions would need AWS credentials, and in our Academy account those are temporary session keys that expire and must be refreshed into repository secrets. CodeBuild runs inside the AWS account and uses an IAM service role, so no keys leave AWS, but setting it up normally means creating that role and its policies, and IAM writes are denied in the Academy account, so I could not build the full AWS-native pipeline here. For this course I recommend GitHub Actions with GHCR, because it needs no stored cloud credentials and everything in this lab actually worked in it. In a company already running its workloads on AWS, I would lean towards CodeBuild and ECR so the images sit next to ECS or EKS and access is controlled through IAM.

## Experiments

### Experiment 1: Invert the layer order

**Prediction.** If COPY app.py ./ moves above the requirements lines, a one-word change to app.py will invalidate that layer and everything after it, so pip install will run again and the rebuild will take several seconds instead of under one.

**What I saw.** With the inverted Dockerfile the rebuild after a one-word edit took 4.343 s and pip install ran again instead of showing CACHED, compared with 0.635 s for my normal slim Dockerfile.

**Explanation.** Docker caches layers in order, and once one layer's input changes every layer after it is rebuilt. Putting the file that changes most often above the slow dependency install means every future code change pays for the full install, which is why the position of one COPY line decides the cost of every rebuild.

### Experiment 2: Delete the .dockerignore

**Prediction.** Without .dockerignore the build context will grow, but the slim image will stay the same size because it only copies requirements.txt and app.py by name.

**What I saw.** The slim image stayed 130MB, every layer was CACHED, and ls -a /app showed only app.py and requirements.txt. The build context also stayed at 473B, which I did not expect.

**Explanation.** BuildKit only transfers the files that COPY instructions actually ask for, so a Dockerfile that copies two named files is not affected by .dockerignore at all. The naive Dockerfile is different: COPY . . asks for the whole folder, which is why its context was 831B and README.md, the evidence folder and the tests ended up inside its image. So .dockerignore matters most exactly where the Dockerfile is careless.
