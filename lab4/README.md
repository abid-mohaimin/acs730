# ACS730 Lab 4

## Image size: naive vs slim

| Image | Base image | Size | Rebuild time after a one-line code change |
|---|---|---|---|
| acs730-lab4:naive | python:latest (1.13GB) | 1.15GB | 5.313 s |
| acs730-lab4:slim | python:3.12-slim-bookworm (124MB) | 130MB | 0.635 s |

**How much of the difference is the base image.** The two images differ by about 1.02GB and the two base images alone differ by about 1.0GB, so roughly 99% of the gap comes from choosing python:latest, which ships a full Debian with build tools, over the slim tag; most of the rest is the pip install layer, which is 17.8MB in the naive image against 6.38MB in the slim one because the slim Dockerfile uses --no-cache-dir.

**Whether the dependency layer is CACHED on a code-only rebuild.** In the slim image the pip install layer showed CACHED after a one-word edit to app.py and the rebuild took 0.635 s, while in the naive image pip install ran again (4.7 s of a 5.313 s rebuild) because COPY . . comes before RUN pip install, so any code change invalidates the install layer.

**What .dockerignore kept out of the context.** The build context went from 831B for the naive build without a .dockerignore to 473B for the slim build, because .dockerignore kept README.md, the evidence folder and the Dockerfiles out; .git never appeared in either build because the context is lab4/ and .git lives at the repository root.
