# Hatch

Hatch is a GitHub Action that uses [openapi-generator](https://github.com/OpenAPITools/openapi-generator) to automatically generate and publish a TypeScript-Axios API client for your service, based on your service's OpenAPI v3 spec.

## Prerequisites

In order to be able to use this Action in the CI/CD pipeline of your service, there are two prerequisites:

1. Your repository must have an associated NPM package registry, and you need a read/write registry token that you can pass into the Action.
2. The Action must be able to access, online, the OpenAPI v3 spec for your service. 
   At Birdie, we use an earlier step of our CI/CD pipeline to deploy the relevant service, which expose an endpoint to fetch the latest version of our OpenAPI spec. That means that when Hatch runs, it can access the latest version. 

## How to use


Once you have the prerequisites in place, you can include this Action in your GitHub workflow. The Action requires 4 parameters to be passed in:

| Name                     | Description                                                                                      |
| -----------              | -----------                                                                                      |
| service_name             | The name of the service for which you wish to generate a client                                  |
| openapi_spec_url         | The URL pointing at the service's OpenAPI v3 spec in JSON format                                 |
| registry_namespace       | The name of the GitHub package registry namespace (without the @) of which your service is part. |
| registry_token           | A read/write access token for the package registry, used to publish the generated client.        |

See below for an example configuration:

```yaml
generate-api-client:
  name: Generate API client
  needs: <any prerequisite earlier job>
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v2
    - name: Run Hatch action
      uses: birdiecare/hatch@v0.0.12 
      with:
        service_name: my-service # the generated client will be named "my-service-client"
        openapi_spec_url: https://my-service.io/docs.json
        registry_namespace: mycompany # the package will be published as @mycompany/my-service-client
        registry_token: ${{ secrets.MY_REGISTRY_TOKEN }}
```

### Exposing DTO classes using Hatch

At [Birdie](https://birdie.care), we use [NestJS and Swagger](https://docs.nestjs.com/openapi/introduction) to annotate the DTO classes we use for our endpoints and RPC operations. For some of our use cases, it was helpful to have these full, Swagger-annotated DTO classes available as part of the generated client package, so that other services making use of this client have access to these annotations instead of just the interfaces provided by `openapi-generator`.

To support this use case, the Hatch action can scan the `src` folder of your service's git repo for files matching the `*.public-models.ts` glob. If you wish to include Swagger-annotated (or other) DTO classes in the generated client package, then make sure to name them accordingly.

Once included, these DTOs can be imported from the generated client:


```ts
import { MyDTO } from '@mycompany/my-service-client/models/my-models.public-models';
```
⚠️  Note that public model files currently do not support any other imports than `@nestjs/swagger` and `class-validator`. If you import anything else, they will fail to compile.

## How does Hatch work "under the hood"?

### openapi-generator
Hatch uses openapi-generator to generate a client from your OpenAPI v3 spec. openapi-generator has many "generators" to allow users to generate different types of clients; the one used by Hatch is the [typescript-axios generator](https://openapi-generator.tech/docs/generators/typescript-axios). Hatch currently does not allow changing the type of generator used; if you wish to use Hatch for a different target you will have to fork this repo and amend it (or open a PR to allow configuring the generator used 🤩).

The version of openapi-generator used is fixed in the `generate-client.sh` script (currently using v4.3.0.).

### Building and publishing the package
Once a client is generated using openapi-generator, Hatch compares the created client (and any included public models) against the latest published version of the client from your package registry. If the client has changed (because your spec has changed), or if there is no previous version, it will continue to publish the newly generated client to your GitHub package registry.

Hatch first compiles the Typescript code so that the package can be published, using [this](templates/tsconfig.json) tsconfig, before creating an NPM package. The generated package will contain a `package.json` with basic information and the required dependencies. The template used for this can be found [here](templates/package.json.template). 

The version of each published package is automatically generated based on the date of publication, following the format: `0.0.YYYYMMDDHHMMSS`. 

## Troubleshooting

While using Hatch at Birdie, it has been stable and failures have been relatively rare. Where we have seen failures, they have generally been caused by one of the following reasons:

- The OpenAPI spec not being available at the specified URL
- The OpenAPI spec not using v3 of the spec
- Invalid Swagger annotations used in our application code, leading to an invalid OpenAPI spec which crashes openapi-generator
- A bug in the version of openapi-generator used, which was resolved after using a newer version

If the Action fails, make sure to look at its logs, which will tell you at which step it has failed. If none of the above issues appear to be the case, then please feel free to open an issue.
