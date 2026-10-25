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
