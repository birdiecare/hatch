FROM timbru31/java-node
COPY generate-client.sh .
RUN mkdir /client
COPY /templates/tsconfig.json ./client
COPY /templates/package.json.template ./client
COPY /templates/package-lock.json ./client
ENTRYPOINT ["/generate-client.sh"]
