# Midterm Practice -- Notes

## Task 5: git hygiene

Deleting the .tfstate file and the hard-coded key in a new commit only removes them from the latest version of the repository, because the earlier commit still holds both in the Git history where anyone with access to the repo can check them out, so the key has to be treated as leaked and revoked, and the history rewritten if the files need to be gone for good.
