FROM timbru31/java-node:latest@sha256:6c96ea933792cdbb5e068fcc0e67644a174b44683c375cab57a2efb4a24aafd3
COPY generate-client.sh .
RUN mkdir /client
COPY /templates/tsconfig.json ./client
COPY /templates/package.json.template ./client
COPY /templates/package-lock.json ./client
ENTRYPOINT ["/generate-client.sh"]
