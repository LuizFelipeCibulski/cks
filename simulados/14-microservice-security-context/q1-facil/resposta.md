## Resposta

Yaml de resposta:
```
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
  namespace: sec-ctx
  labels:
    app: secure-app
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    volumeMounts:
    - name: data
      mountPath: /data
    securityContext:
      allowPrivilegeEscalation: false   #não permitir escalonamento de privilégio
      capabilities:                     #remover todas as Linux capabilities
        drop: ["ALL"]
      readOnlyRootFilesystem: true      #sistema de arquivos raiz somente leitura
  volumes:
  - name: data
    emptyDir: {}
```