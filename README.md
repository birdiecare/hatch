## Hatch

### Description

Hatch is a GitHub Action that uses [openapi-generator](https://github.com/OpenAPITools/openapi-generator) to automatically generate and publish a TypeScript-axios API client for your service, based on your service's OpenAPI spec.

### Usage

To use this Action, you will need:

- An OpenAPI v3 spec of your service, which is accessible to the Action. Easiest might be to expose an endpoint that serves your service's OpenAPI spec
- A GitHub NPM registry and an access token to publish packages to it

You can include this Action in your GitHub workflow as follows:

```yaml
generate-api-client:
  name: Generate API client
  needs: <any prerequisite earlier job>
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v2 # <-- this one is needed for hatch to access source code
    - name: Run Hatch action
      uses: birdiecare/hatch@v0.0.12 # <-- use current version
      with:
        path: <e.g. https://staging.myservice.com/docs.json>
        name: <Name of your service, e.g. my-service> # the generated client will automatically be called my-service-client
        token: <your GitHub Registry Token>
```

Running this Action will publish an NPM package called `my-service-client` as a package **inside the repository of the service running the Action**.

### Exposing swagger models

If you want to create a proxy endpoint in `core-api`, you would like to import the class decorated with `@nestjs/swagger` decorators to avoid re-declaring the swagger docs.

In that case, the `birdiecare/hatch` action can scan your `src` folder of the git repo in search of all the files matching the `*.public-models.ts` glob. Other files will be ignored, so make sure you put the swagger classes in that file.

Then in the `core-api` you can import the file from `package/models/filename` nested import, e.g.:
```ts
import { IdentifierMapping } from '@birdiecare/rostering-integrations-client/models/identifier-mapping.public-models';
```

Be aware that the public models files shouldn't have any other imports than `@nestjs/swagger` and `class-validator` ones! Otherwise (especially in case of relative imports) it gonna fail to compile.

### Templating

[openapi-generator](https://github.com/OpenAPITools/openapi-generator) works by running a specified [code generator](https://github.com/OpenAPITools/openapi-generator/blob/master/docs/generators.md) on an OpenAPI spec. Hatch uses [typescript-axios](https://github.com/OpenAPITools/openapi-generator/blob/master/docs/generators/typescript-axios.md) for this.

The code generator generates an API client based on the OpenAPI spec using [Mustache](https://mustache.github.io) templates. These templates are shipped with the relevant code generator. The `/templates/openapi-generator/typescript-axios` folder of this repo houses the templates used by this Action. They are unchanged from the standard templates used by `typescript-axios`, but are included so that it is easy to make changes if your use case requires them.
