#!/usr/bin/env sh

# pull in jq (for json string building)
apt-get update
apt-get -y install jq

echo "I have these vars: $1 $2"

# pull openapi-generator binary
wget --quiet https://repo1.maven.org/maven2/org/openapitools/openapi-generator-cli/4.2.2/openapi-generator-cli-4.2.2.jar -O openapi-generator-cli.jar

# run generator
java -jar openapi-generator-cli.jar generate \
    --input-spec $1 \
    --generator-name typescript-axios \
    --additional-properties=supportsES6=true,modelPropertyNaming=original,withInterfaces=true \
    --template-dir /openapi-templates \
    --output /client

cd client

# write package.json with package name, description, version, and github repo
DATE=$(date -u +"%Y%m%d%H%M%S")
cat package.json.template | jq --arg pn "$2" '.name="@birdiecare/\($pn)-client"' | jq --arg pn "$2" '.description="Autogenerated API client for \($pn) service."' | jq --arg pn "$2" '.repository.url="ssh://git@github.com/birdiecare/\($pn).git"' | jq --arg date "$DATE" '.version="0.0.\($date)"' > package.json

# install dependencies and build
npm i
npm run build

# copy package.json to dist folder and publish to GitHub package registry
cp package.json dist/
cd dist
echo "@birdiecare:registry=https://npm.pkg.github.com/" >> .npmrc
echo "//npm.pkg.github.com/:_authToken=$3" >> .npmrc
npm publish
