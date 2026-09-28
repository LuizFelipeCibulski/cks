Create two Docker containers sharing the same PID namespace:

Rodar o primeiro container: 
docker run -d --name app1 nginx:alpine sleep infinity

Rodar o segundo container atachando diretamente no namespace do primeiro
docker run -d --pid container:app1 --name app2 nginx:alpine sleep infinity

Create two Podman containers sharing the same PID namespace

Rodar o primeiro container: 
podman run -d --name app1 nginx:alpine sleep infinity

Rodar o segundo container atachando diretamente no namespace do primeiro
podman run -d --pid container:app1 --name app2 nginx:alpine sleep infinity