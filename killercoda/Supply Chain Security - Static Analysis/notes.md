Manually Analyse K8s YAML files

apiVersion: v1
kind: Pod
metadata:
  name: pod
spec:
  containers:
  - name: main
    image: alpine
    command: ["/bin/sleep", "999999"]
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5

## Não tem segurança 


apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  labels:
    app: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        securityContext:
          capabilities:
            drop: []
          allowPrivilegeEscalation: true
        image: httpd
        readinessProbe:
          exec:
            command:
            - cat
            - /tmp/healthy
          initialDelaySeconds: 5
          periodSeconds: 5

## allowPrivilegeEscalation: true

apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None
  selector:
    app: nginx
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  selector:
    matchLabels:
      app: nginx
  serviceName: "nginx"
  replicas: 3
  minReadySeconds: 10
  template:
    metadata:
      labels:
        app: nginx
    spec:
      terminationGracePeriodSeconds: 10
      containers:
      - name: nginx
        image: registry.k8s.io/nginx-slim:0.8
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
        readinessProbe:
          httpGet:
            scheme: HTTPS
            path: /index.html
            port: 8443
          initialDelaySeconds: 10
          periodSeconds: 5
        startupProbe:
          httpGet:
            scheme: HTTPS
            path: /index.html
            port: 8443
          initialDelaySeconds: 10
          periodSeconds: 5
        securityContext:
          privileged: true
        livenessProbe:
          httpGet:
            scheme: HTTPS
            path: /index.html
            port: 8443
          initialDelaySeconds: 10
          periodSeconds: 5
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: "my-storage-class"
      resources:
        requests:
          storage: 1Gi

## securityContext: privileged: true

----


Manually Analyse Dockerfiles

FROM ubuntu
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y golang-go
COPY app.go .
RUN CGO_ENABLED=0 go build app.go
CMD ["./app"]

## sem segurança e build unica


FROM ubuntu
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y golang-go
COPY app.go .
RUN CGO_ENABLED=0 go build app.go
FROM alpine:3.11.6
COPY --from=0 /app .
CMD ["./app"]

## Rodando como root

FROM ubuntu
COPY my.cnf /etc/mysql/conf.d/my.cnf
COPY mysqld_charset.cnf /etc/mysql/conf.d/mysqld_charset.cnf
RUN apt-get update && \
    apt-get -yq install mysql-server-5.6 &&
COPY import_sql.sh /import_sql.sh
COPY run.sh /run.sh
RUN echo $SECRET_TOKEN > /tmp/token
RUN /etc/register.sh /tmp/token
RUN rm /tmp/token
EXPOSE 3306
CMD ["/run.sh"]

## Echo no token