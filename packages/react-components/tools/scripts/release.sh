#!/bin/bash -e
#
# Release script

# Export RELEASE env var
export RELEASE=1

# Verifies that is running from the right directory
if ! [ -e tools/scripts/release.sh ]; then
  echo >&2 "Please run tools/scripts/release.sh from the repo root"
  exit 1
fi

LAST_COMMIT=$(git log -1 --pretty=%B)                  # Save last commit name
ORIGIN_DEST="origin"                                   # git origin of destination
PACKAGE_NAME=$(node -p "require('./package').name")    # Package name
NEXT_VERSION=$(node -p "require('./package').version") # Get new version

# Publish git tag
TAG_NAME="$PACKAGE_NAME@$NEXT_VERSION"
TAG_EXISTS=$(git tag -l "$TAG_NAME")

if [ ! -z "$TAG_EXISTS" ]; then
  echo "There is already a tag $TAG_EXISTS in git. Skiping git deploy."
else
  echo "Deploying $NEXT_VERSION to git"

  TEMP_TAG_BRANCH="$PACKAGE_NAME-temp"   # Name of the temporary branch for the package
  TAG_NAME_LATEST="$PACKAGE_NAME@latest" # Name of latest git tag

  ## Change to the temporary branch
  git branch -D "$TEMP_TAG_BRANCH"
  git checkout -b "$TEMP_TAG_BRANCH"

  ## Build module
  NODE_ENV=production npm run build -- --bail

  ## Remove non related files
  rm -rf ../../bin ../../landing ../../lib ../../vendor
  rm ../../.babelrc ../../.eslintrc ../../.gitignore ../../Gruntfile.js ../../gulpfile.js ../../README.md ../../app.json ../../bower.json ../../component.json ../../index.js ../../index.styl ../../lerna.json ../../package.json ../../webpack.config.js

  ## Add build dir to git and remove packages folder
  grep -v '^build$' .gitignore > .gitignore2
  mv .gitignore2 .gitignore

  ## Move actual package to root
  mv package.json .gitignore LICENSE.md README.md src build ../../

  cd ../../
  rm -rf packages

  ## Commit changes
  git add .
  git add --force build/*
  git commit -am "$NEXT_VERSION build"

  ## Create git tags
  git tag $TAG_NAME
  git tag $TAG_NAME_LATEST -f

  ## Publish git tags
  git push $ORIGIN_DEST $TAG_NAME
  git push $ORIGIN_DEST $TAG_NAME_LATEST -f

  ## Remove temporary branch and switch to previous branch
  git checkout -
  git branch -D $TEMP_TAG_BRANCH
fi
