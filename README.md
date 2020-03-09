## Hatch

### Description
Hatch is a GitHub Action that uses [openapi-generator](https://github.com/OpenAPITools/openapi-generator) to automatically generate and publish a TypeScript-axios API client for your service, based on your service's OpenAPI spec.

### Usage
To use this Action, you will need: 
* An OpenAPI v3 spec of your service, which is accessible to the Action. Easiest might be to expose an endpoint that serves your service's OpenAPI spec
* A GitHub NPM registry and an access token to publish packages to it

You can include this Action in your GitHub workflow as follows:

```yaml
generate-api-client:
  name: Generate API client
  needs: <any prerequisite earlier job>
  runs-on: ubuntu-latest
  steps:
  - name: Run Hatch Action
    uses: birdiecare/hatch@v0.0.1 # <-- use current version
    with:
      path: <e.g. https://staging.myservice.com/docs.json>
      name: <Name of your service, e.g. my-service> # the generated client will automatically be called my-service-client
      token: <your GitHub Registry Token>
```

Running this Action will publish an NPM package called `my-service-client` as a package __inside the repository of the service running the Action__.

### Templating
[openapi-generator](https://github.com/OpenAPITools/openapi-generator) works by running a specified [code generator](https://github.com/OpenAPITools/openapi-generator/blob/master/docs/generators.md) on an OpenAPI spec. Hatch uses [typescript-axios](https://github.com/OpenAPITools/openapi-generator/blob/master/docs/generators/typescript-axios.md) for this. 

The code generator generates an API client based on the OpenAPI spec using [Mustache](https://mustache.github.io) templates. These templates are shipped with the relevant code generator. The `/templates/openapi-generator/typescript-axios` folder of this repo houses the templates used by this Action. They are unchanged from the standard templates used by `typescript-axios`, but are included so that it is easy to make changes if your use case requires them.
