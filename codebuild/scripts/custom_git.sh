#!/bin/bash

echo start
depth=10
function usage {
  {
    echo "Usage:"
    echo "   ${BASH_SOURCE[0]} <REPO_URL> <BRANCH>"
    echo "      REPO_URL - the URL for the CodeCommit repository"
    echo "      BRANCH - the branch to check out. Defaults to the default branch."
    echo "      TAG_EXT - (optional) find the tag with the specified extension. Reset to the tag. Defaults to not reset."
  } >&2
}

# Confirm that there are at least three arguments
if [ "$#" -lt 2 ]; then
  usage
  exit 1
fi

# Confirm that CODEBUILD_RESOLVED_SOURCE_VERSION is set
if [ -z "${CODEBUILD_RESOLVED_SOURCE_VERSION:-}" ]; then
  {
    echo "Error: CODEBUILD_RESOLVED_SOURCE_VERSION is not set"
  } >&2 
  usage
  exit 1
fi

# Read arguments
REPO_URL="$1"
BRANCH=$2
if [ ! -z "${3:-}" ]; then
  TAG_EXT=$3
fi
# Remember the working directory
WORKING_DIR="$(pwd)"

# Check out the repository to a temporary directory
# Note that --quiet doesn't work on the current CodeBuild agents, but
# hopefully it will in the future
echo create realworkdir
TEMP_FOLDER=realworkdir
rm -rf $TEMP_FOLDER
rm -rf .git
sleep 3

#TEMP_FOLDER="$(mktemp -d)"
git clone --single-branch --branch "$BRANCH" --depth 10 --quiet "$REPO_URL" "$TEMP_FOLDER"

# Wind the repository back to the specified branch and commit
cd "$TEMP_FOLDER"
git fetch --tags
git checkout "$BRANCH"

if [ ! -z "$TAG_EXT" ]
then
  tag=$(git tag --merged "$BRANCH" -l sort=refname *$TAG_EXT | tail -1)
  echo $tag
  if [ -z "$tag" ]
    then
      echo cannot find tag. aborting ...
      exit
  fi
  commit_id=$(git rev-list -n 1 $tag)
else
  commit_id=$(git rev-parse HEAD)
fi

echo reset to "$commit_id"
git reset --hard "$commit_id"

# Confirm that the git checkout worked
if [ ! -d  .git ] ; then
  {
    echo "Error: .git directory missing. Git checkout probably failed"
  } >&2 
  exit 1
fi

#mv .git "$WORKING_DIR"