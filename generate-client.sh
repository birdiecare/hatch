#!/usr/bin/env sh

# This shell script uses a specified swagger document to generate a typescript-axios API client using openapi-generator.
# It then compares this generated client to the previous version and, if it has changed, publishes it as an NPM package.
#

echo "Hatch action started."

echo "Downloading and installing prerequisites..."
apt-get update
apt-get -y install wget jq
wget --quiet https://repo1.maven.org/maven2/org/openapitools/openapi-generator-cli/4.3.0/openapi-generator-cli-4.3.0.jar -O openapi-generator-cli.jar
if [ $? -ne 0 ]
then
  echo "ERROR: cannot download openapi generator binary; aborting."
  exit 1
fi
echo "[SUCCESS]"

echo "Running openapi-generator using swagger doc at $INPUT_PATH..."
java -jar openapi-generator-cli.jar generate \
    --input-spec $INPUT_PATH \
    --generator-name typescript-axios \
    --additional-properties=supportsES6=true,modelPropertyNaming=original,withInterfaces=true \
    --output /client
if [ $? -ne 0 ]
then
  echo "ERROR: something went wrong running the openapi generator; aborting."
  exit 1
fi
echo "[SUCCESS]"


echo "Creating package.json from template..."
cd /client
DATE=$(date -u +"%Y%m%d%H%M%S")
cat package.json.template | jq --arg pn "$INPUT_NAME" '.name="@birdiecare/\($pn)-client"' | jq --arg pn "$INPUT_NAME" '.description="Autogenerated API client for \($pn) service."' | jq --arg pn "$INPUT_NAME" '.repository.url="ssh://git@github.com/birdiecare/\($pn).git"' | jq --arg date "$DATE" '.version="0.0.\($date)"' > package.json
if [ $? -ne 0 ]
then
  echo "ERROR: something went wrong writing package.json; aborting."
  exit 1
fi
echo "[SUCCESS]"

echo "Installing dependencies and building new client package..."
npm i
npm run build
if [ $? -ne 0 ]
then
  echo "ERROR: failed to build package; aborting"
  exit 1
fi
echo "[SUCCESS]"

echo "Fetching latest published version of client package..."
# build npmrc for access to private package repo - also required to publish in next step
echo "@$INPUT_REGISTRY_NAMESPACE:registry=https://npm.pkg.github.com/" >> .npmrc
echo "//npm.pkg.github.com/:_authToken=$INPUT_TOKEN" >> .npmrc
mkdir old_version
cp .npmrc old_version/
cd old_version
npm init --yes
npm i @$INPUT_REGISTRY_NAMESPACE/$INPUT_NAME-client
if [ $? -eq 0 ]
then
  echo "[SUCCESS]"
  echo "Calculating differences between latest published version and newly built package..."
  cd ..
  cksum dist/*.js | awk '{print $1":"$2}' >> new_checksums
  cksum dist/*.d.ts | awk '{print $1":"$2}' >> new_checksums
  cksum old_version/node_modules/@$INPUT_REGISTRY_NAMESPACE/$INPUT_NAME-client/*.js | awk '{print $1":"$2}' >> old_checksums
  cksum old_version/node_modules/@$INPUT_REGISTRY_NAMESPACE/$INPUT_NAME-client/*.d.ts | awk '{print $1":"$2}' >> old_checksums
  diff old_checksums new_checksums
  if [ $? -eq 0 ]
  then
    echo "> No differences to publish, aborting Hatch action <"
    exit 0
  elif [ $? -ne 1 ]
  then
    echo "ERROR: something went wrong comparing old to new package, aborting build."
    exit 1
  fi
  echo "Differences found between old and new package"
else
  echo "ERROR: failed to fetch latest published version; skipping calculating differences"
  cd ..
fi

echo "Publishing new package..."
# copy package.json to dist folder and publish to GitHub package registry
cp package.json dist/
cp .npmrc dist/
cd dist
npm publish
if [ $? -ne 0 ]
then
  echo "ERROR: something went wrong publishing the NPM package."
  exit 1
else
  echo "[SUCCESS: Hatch action completed successfully]"
  exit 0
fi
