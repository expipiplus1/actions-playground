#!/usr/bin/env bash

set -e

help=
requireFirst=
releaseNote=release-note.md
assets=assets

# from https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help) help=1 ;;
  --require-first)
    requireFirst="$2"
    shift
    ;;
  --release-note)
    releaseNote="$2"
    shift
    ;;
  --assets)
    assets="$2"
    shift
    ;;
  *)
    echo "Unknown parameter passed: $1" >&2
    exit 1
    ;;
  esac
  shift
done

if [ $help ]; then
  me=$(basename "$0")
  cat <<EOF
$me: Create releases for the tags on HEAD. Fails when there are no relevant
     tags.

Options:
  --require-first: Exit without doing anything if this doesn't match the
      first package in the release. This is useful for CI scripts which are
      spawned multiple times on the same commmit with different tags, passing
      the spawning tag here will ensure that only the "highest priority" job
      actually does anything.
  --release-note: The file into which to write a note for the release in
      markdown. Default "release-note.md".
  --assets: A directory into which release assets will be placed, will be
      created if it is absent. Default "assets".
  --help: show this message
EOF
  exit 0
fi

################################################################
# Releases every package with an appropriate tag
################################################################

tagNames=(^v ^other-v ^third-v)
funNames=(release1 release2 release3)

# Get the tags on HEAD
mapfile -t tags < <(git tag --points-at HEAD | sort)

# Order them according to the arrays above
declare -a tagMap
for i in "${tags[@]}"; do
  for r in "${!tagNames[@]}"; do
    if [[ "$i" =~ ${tagNames[$r]} ]]; then
      tagMap[$r]=$i
    fi
  done
done

if [ ${#tagMap[@]} -eq 0 ]; then
  echo >&2 "No relevant tags to release"
  exit
fi

# If we're not the job running on the most important release, exit
for first in "${tagMap[@]}"; do break; done
if [ "$requireFirst" ] && [ "$requireFirst" != "$first" ]; then
  echo >&2 "Skipping because --require-first didn't match"
  exit
fi

releaseTitle="Release $(printf "%s" "${tagMap[*]}" | sed 's/ /, /g')"
echo "$releaseTitle" >&2

printf "%s\n\n" "$releaseTitle" >"$releaseNote"

release1() {
  mkdir -p "$assets"
  tar czv ./package.yaml >assets/package.tar.gz
  echo "## Main package changelog" >>"$releaseNote"
  echo "rhubarb rhubarb" >>"$releaseNote"
}

release2() {
  mkdir -p "$assets"
  tar czv ./other-package.yaml >assets/other-package.tar.gz
  echo "## Second package changelog" >>"$releaseNote"
  echo "rhubarb rhubarb" >>"$releaseNote"
}

release3() {
  mkdir -p "$assets"
  tar czv ./third-package.yaml >assets/third-package.tar.gz
  echo "## Third package changelog" >>"$releaseNote"
  echo "rhubarb rhubarb" >>"$releaseNote"
}

for i in "${!tagMap[@]}"; do
  ${funNames[$i]}
  echo >>"$releaseNote"
done
