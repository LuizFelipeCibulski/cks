## Resposta

Node01:
```
cat <<EOF | sudo tee /etc/containerd/config.toml
version = 2
[plugins."io.containerd.runtime.v1.linux"]
  shim_debug = true
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
EOF


```


Controlplane:
```
sandbox.cks.io/runtime=gvisor

apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor-sandbox
handler: runsc
scheduling:
  nodeSelector:
   sandbox.cks.io/runtime: gvisor


k get deployments.apps -n payments 
NAME        READY   UP-TO-DATE   AVAILABLE   AGE
gateway     2/2     2            2           4m5s
processor   1/1     1            1           4m5s
reports     1/1     1            1           4m5s


editar e adicionar runtimeClassName: gvisor-sandbox

k exec -it -n payments gateway-7f57675794-8blgv -- dmesg > /opt/course/16/q3/dmesg.txt
```