#!/usr/bin/env sh

# This shell script runs through the following steps to generate and publish a client based on the provided OpenAPI v3 specification:
# 1. Download and install prerequisites.
# 2. Use openapi-generator to generate an API client based on the provided OpenAPI v3 spec
# 3. Crawl for any public models (named <xxx>.public-models.ts) to include in the package.
# 4. Build the new package
# 5. Fetch the current version of the package, if available.
# 6. If there are differences, or if no previous version could be fetched, publish the new version to the NPM registry

echo "Hatch action started."

# Step 1: Download and install prerequisites
echo "Downloading and installing prerequisites..."
apt-get update
apt-get -y install wget jq
wget --quiet https://repo1.maven.org/maven2/org/openapitools/openapi-generator-cli/7.4.0/openapi-generator-cli-7.4.0.jar -O openapi-generator-cli.jar
if [ $? -ne 0 ]
then
  echo "ERROR: cannot download openapi generator binary; aborting."
  exit 1
fi
echo "[SUCCESS]"

# Step 2: Generate client
echo "Running openapi-generator using swagger doc at $INPUT_OPENAPI_SPEC_URL..."
java -jar openapi-generator-cli.jar generate \
    --input-spec $INPUT_OPENAPI_SPEC_URL \
    --generator-name typescript-axios \
    --additional-properties=supportsES6=true,modelPropertyNaming=original,withInterfaces=true \
    $(if [ "${INPUT_SKIP_VALIDATE_SPEC:-false}" = "true" ]; then echo "--skip-validate-spec"; fi) \
    --output /client
if [ $? -ne 0 ]
then
  echo "ERROR: something went wrong running the openapi generator; aborting."
  exit 1
fi
echo "[SUCCESS]"

# Step 3: Crawl for public models
echo "Checking GitHub repository folder..."
cd $GITHUB_WORKSPACE/src

echo "Searching for models files..."
globs=$(find . -iname '*.public-models.ts')

if [ -z "$globs" ]; then
  echo "No models found"
else
  echo "Copying models files to /client/models"
  mkdir -p /client/models
  for path in $globs; do
    echo - $(basename $path)
    cp $GITHUB_WORKSPACE/src/$path /client/models
  done
fi

# Step 4: Build client package
echo "Creating package.json from template..."
cd /client
DATE=$(date -u +"%Y%m%d%H%M%S")
cat package.json.template \
	| jq --arg NAME "$INPUT_PACKAGE_NAME" \
	     --arg REGISTRY "$INPUT_REGISTRY_NAMESPACE" \
	     '.name="\($REGISTRY)/\($NAME)"' \
	| jq --arg NAME "$INPUT_PACKAGE_NAME" \
	     '.description="\($NAME): API client generated using openapi-generator and @birdiecare/hatch"' \
	| jq --arg REPO_URL "$INPUT_REPOSITORY_URL" \
	     '.repository.url="\($REPO_URL)"' \
	| jq --arg VERSION "$DATE" \
	     '.version="0.0.\($VERSION)"' \
	> package.json

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

# Step 5: Fetch current version, if available, and diff against new
echo "Fetching latest published version of client package..."
echo "$INPUT_REGISTRY_NAMESPACE:registry=https://npm.pkg.github.com/" >> .npmrc
echo "//npm.pkg.github.com/:_authToken=$INPUT_REGISTRY_TOKEN" >> .npmrc
mkdir old_version
cp .npmrc old_version/
cd old_version
npm init --yes
npm i $INPUT_REGISTRY_NAMESPACE/$INPUT_PACKAGE_NAME
if [ $? -eq 0 ]
then
  echo "[SUCCESS]"
  echo "Calculating differences between latest published version and newly built package..."
  cd ..
  cksum dist/*.js | awk '{print $1":"$2}' >> new_checksums
  cksum dist/*.d.ts | awk '{print $1":"$2}' >> new_checksums
  cksum dist/models/** | awk '{print $1":"$2}' >> new_checksums
  cksum old_version/node_modules/$INPUT_REGISTRY_NAMESPACE/$INPUT_PACKAGE_NAME/*.js | awk '{print $1":"$2}' >> old_checksums
  cksum old_version/node_modules/$INPUT_REGISTRY_NAMESPACE/$INPUT_PACKAGE_NAME/*.d.ts | awk '{print $1":"$2}' >> old_checksums
  cksum old_version/node_modules/$INPUT_REGISTRY_NAMESPACE/$INPUT_PACKAGE_NAME/models/** | awk '{print $1":"$2}' >> old_checksums
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
  echo "Failed to fetch latest published version; skipping calculating differences"
  cd ..
fi

# Step 6: Publish package if there have been changes
echo "Publishing new package..."
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
