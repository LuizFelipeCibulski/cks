## Resposta

Yamls da respota:
```
apiVersion: v1
kind: Pod
metadata:
  name: legacy-agent
  namespace: kubesec-lab
  labels:
    app: legacy-agent
spec:
  automountServiceAccountToken: false
  hostPID: false
  hostNetwork: false
  containers:
  - name: agent
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext:
      privileged: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
      runAsUser: 1000
      runAsGroup: 3000
```