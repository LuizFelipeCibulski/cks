## Resposta

Alterar parametros no arquivo */etc/kubernetes/manifests/kube-apiserver.yaml*

```
apiVersion: v1
kind: Pod
metadata:
  annotations:
    kubeadm.kubernetes.io/kube-apiserver.advertise-address.endpoint: 172.30.1.2:6443
  labels:
    component: kube-apiserver
    tier: control-plane
  name: kube-apiserver
  namespace: kube-system
spec:
  containers:
  - command:
    - kube-apiserver
    - --profiling=false
    - --advertise-address=172.30.1.2
    - --allow-privileged=true
    - --authorization-mode=Node,RBAC
    - --client-ca-file=/etc/kubernetes/pki/ca.crt
    - --enable-admission-plugins=NodeRestriction
```

```
chown root:root -R /etc/kubernetes/pki

chmod 600 -R /etc/kubernetes/pki/*.key

chmod 600 -R /etc/kubernetes/pki/etcd/*.key

chmod 700 -R /var/lib/etcd
```