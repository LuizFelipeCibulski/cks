## Resposta

```
apparmor_parser /opt/course/11/q1/k8s-deny-write

apiVersion: v1
kind: Pod
metadata:
  name: writer
  namespace: apparmor-q1
spec:
  nodeName: controlplane
  containers:
  - name: writer
    image: busybox:1.36
    command: ["sh", "-c", "echo iniciado; sleep 1d"]
    securityContext:
      appArmorProfile:
        type: Localhost
        localhostProfile: k8s-deny-write
```