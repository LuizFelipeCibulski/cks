Reduce the footprint of a given Dockerfile

FROM alpine:3.12.3

RUN adduser -D -g '' appuser

CMD sh -c 'sleep 1d'
docker build . -t base-image


Rodar um container e validar qual usuario está executando o comando

docker run -d --name c1 base-image sleep infinity

docker exec -it c1 ps aux



Alterar para user appuser

FROM alpine:3.12.3

RUN adduser -D -g '' appuser

USER appuser

CMD sh -c 'sleep 1d'
docker build . -t base-image

Rodar um container e validar qual usuario está executando o comando

docker run -d --name c2 base-image sleep infinity

docker exec -it c2 ps aux



---

Harden a given Docker Container

FROM ubuntu
RUN apt-get update
RUN apt-get -y install curl
ENV URL https://google.com/this-will-fail?secret-token=
CMD ["sh", "-c", "curl --head $URL=2e064aad-3a90-4cde-ad86-16fad1f8943e"]


FROM ubuntu:20.04
RUN apt-get update && apt-get -y install curl
ENV URL https://google.com/this-will-fail?secret-token=
RUN rm -rf /bin/bash
CMD ["sh", "-c", "curl --head $URL$TOKEN"]