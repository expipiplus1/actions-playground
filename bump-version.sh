#!/usr/bin/env bash

set -e

echo $#

help=
tagPrefix=v
ignoreDirty=
createTag=
version=
packageDir=.
commitMessageFile=

# from https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help) help=1 ;;
  -v | --version)
    version="$2"
    shift
    ;;
  -d | --package-directory)
    packageDir="$2"
    shift
    ;;
  --create-tags) createTag=1 ;;
  -t | --tag-prefix)
    tagPrefix="$2"
    shift
    ;;
  --commit-message-file)
    commitMessageFile="$2"
    shift
    ;;
  --ignore-dirty) ignoreDirty=1 ;;
  *)
    echo "Unknown parameter passed: $1"
    exit 1
    ;;
  esac
  shift
done

if [ $help ]; then
  cat <<EOF
    Options:
      -v|--version 1.2.3       : version to bump to
      -p|--package-directory d : directory containing changelog.md and package.yaml, default .
      --ignore-dirty           : don't exit when the git tree is dirty
      --create-tag             : create tags, default off
      -t|--tag-prefix my-tag-v : prefix for git tag, default: v
      --ignore-old-version     : don't check the old version to ensure an upgrade is happening
      --commit-message-file    : file to write the commit message in instead of committing directly
      --help                   : duh
EOF
  exit 0
fi

if [ -z "$version" ]; then
  echo >&2 "--version required"
  exit 1
fi

if ! [ $ignoreDirty ] && [[ -n $(git status --short --untracked-files=no) ]]; then
  echo >&2 "There are untracked changes in the working tree, please resolve these before making a release"
  exit 1
fi

checkExe() {
  if ! command -v "$1" &>/dev/null; then
    echo "$1 could not be found"
    exit 1
  fi
}

checkExe git
checkExe yq
checkExe hpack

package=$packageDir/package.yaml
changelog=$packageDir/changelog.md

name=$(yq <"$package" --raw-output .name)
oldVersion=$(yq <"$package" --raw-output .version)

if [ "$version" = "$oldVersion" ]; then
  echo >&2 "The package is currently at the requested version ($oldVersion)"
  exit 1
fi

if ! sort --version-sort --check=silent <(printf "%s\n%s" "$oldVersion" "$version"); then
  echo >&2 "The package is currently at a later version ($oldVersion)"
  exit 1
fi

echo >&2 "Bumping version of $name from $oldVersion to $version"

sed -i.bak "s/^version: .*/version: \"$version\"/g" "$package"
git add "$package"

if [ -f "$changelog" ]; then
  sed -i.bak "s/^## WIP$/\0\n\n## [$version] - $(date --iso-8601)/" "$changelog"
  git add "$changelog"
else
  echo >&2 "$changelog not found, not updating"
fi

hpack "$packageDir"
git add "$packageDir/$name.cabal"

tag=$tagPrefix$version
branch="release-$tag"
git checkout -b "$branch"

commitMessage(){
  printf "%s\n\n" "$tag"
  if [ -f "$changelog" ]; then
    awk '/## WIP/{flag=0;next};/##/{flag=flag+1};flag==1' <"$changelog" | sed "/^##/d"
  fi
}

if [ -z "$commitMessageFile" ]; then
  git commit --file <(commitMessage)
else
  commitMessage > "$commitMessageFile"
fi

if [ "$createTag" ]; then
  git tag "$tag"
fi

cat <<EOF
  --------------------------------
  Commands to upload these changes
  --------------------------------

  # Open a PR for this release
  git push --set-upstream origin "$branch"
  git pull-request
  # Wait for CI to complete
  git push --tags
  git checkout master
  git merge "$branch"
  git push
EOF
