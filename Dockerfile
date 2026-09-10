# Pinned by digest: the toolchain that compiles the client (node/npm/java) is as
# much a build input as the packages in the lockfile. OCI index, so it resolves
# per-arch. Currently java 17.0.9 / node 16.20.2 / npm 8.19.4.
# Update: docker pull timbru31/java-node && \
#   docker image inspect timbru31/java-node:latest --format '{{index .RepoDigests 0}}'
FROM timbru31/java-node:latest@sha256:6c96ea933792cdbb5e068fcc0e67644a174b44683c375cab57a2efb4a24aafd3
COPY generate-client.sh .
RUN mkdir /client
COPY /templates/tsconfig.json ./client
COPY /templates/package.json.template ./client
COPY /templates/package-lock.json ./client
ENTRYPOINT ["/generate-client.sh"]
