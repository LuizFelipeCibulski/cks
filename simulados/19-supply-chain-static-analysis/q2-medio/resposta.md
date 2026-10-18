## Resposta


Yamls:
```
cat /opt/course/19/q2/insecure-files.txt 
Dockerfile-2
Dockerfile-3
deploy-b.yaml
```

```
kube-linter lint /opt/course/19/q2/deploy-b.yaml > /opt/course/19/q2/kube-linter-b.txt
```

/opt/course/19/q2/Dockerfile-3
```
FROM node:20.11-alpine
WORKDIR /app
COPY package.json package-lock.json ./
# chave de deploy para baixar dependencias do repositorio git privado
#COPY id_rsa /root/.ssh/id_rsa
#RUN chmod 600 /root/.ssh/id_rsa && npm ci --omit=dev
COPY . .
RUN chown -R node:node /app
USER node
EXPOSE 3000
# o time de ops pediu acesso total dentro do container para debug
#USER root
CMD ["node", "server.js"]
```