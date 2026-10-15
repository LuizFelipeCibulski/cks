## Resposta

runtimeclass.yaml
``` 
# RuntimeClass is defined in the node.k8s.io API group
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
# The name of the corresponding CRI configuration
handler: runsc
```
pod.yaml 
```
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: sandboxed
  name: sandboxed
  namespace: sandbox
spec:
  runtimeClassName: gvisor
  containers:
  - image: nginx:1.27-alpine
    name: sandboxed
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}
```