## Resposta:


Yamls de reposta:
```
apiVersion: v1
kind: Secret
metadata:
  name: catalog-api
  namespace: static-app
data:
  api-secret: czNjcjN0LTRwMS1rM3ktMjAyNAo=
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
  namespace: static-app
  labels:
    app: catalog
spec:
  replicas: 2
  selector:
    matchLabels:
      app: catalog
  template:
    metadata:
      labels:
        app: catalog
    spec:
      serviceAccountName: default
      automountServiceAccountToken: false
      volumes:
      - name: tmp
        emptyDir: {}
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - catalog
              topologyKey: kubernetes.io/hostname
      containers:
      - name: web
        image: nginxinc/nginx-unprivileged:1.27-alpine
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
        ports:
        - containerPort: 8080
        volumeMounts:
        - mountPath: /tmp
          name: tmp
        env:
        - name: API_SECRET
          valueFrom:
            secretKeyRef:
              name: catalog-api
              key: api-secret
        securityContext:
          privileged: false
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
---
apiVersion: v1
kind: Service
metadata:
  name: catalog
  namespace: static-app
spec:
  selector:
    app: catalog
  ports:
  - name: http
    port: 80
    targetPort: 8080
```