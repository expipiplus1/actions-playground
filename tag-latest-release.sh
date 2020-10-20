#!/usr/bin/env bash

################################################################
# Find the commit where the current version number in package.yaml was set, and
# add an appropriate tag to that version.
################################################################

# This is the version we want to find the first appearance of on the main
# branch (the one followed by --first-parent)
if ! currentVersion=$(yq <package.yaml --exit-status --raw-output .version); then
  echo "Unable to get version from package.yaml"
  exit 1
fi
if ! [[ "$currentVersion" =~ ^[0-9.]+$ ]]; then
  echo "version from package.yaml isn't a valid version: $currentVersion"
  exit 1
fi

tag=v$currentVersion

# Exit if this version already has a tag
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  echo "Tag $tag already exists"
  exit
fi

# The current candidate for the package.yaml changing commit
prev=$(git rev-parse HEAD)

# - Get all the comments on the main branch which touch this file, most recent
#   ones first, starting with the immediate parent
# - If the version has changed between this candidate and the parent, return
#   the candidate
# - Otherwise continue into history, using the parent as the new candidate
while read -r hash; do
  oldVersion=$(git show "$hash":package.yaml | yq .version)
  if [ "$oldVersion" != "$currentVersion" ]; then
    brea
  fi
  prev=$hash
done < <(git log --first-parent --pretty=format:"%H" HEAD~ -- package.yaml)

# The first commit changing the version
firstChange=$prev

# Set the tag
git tag "$tag" "$firstChange"
