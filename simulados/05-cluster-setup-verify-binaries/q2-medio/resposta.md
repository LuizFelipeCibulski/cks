## Respostas


Coletar o binario oficial:
```
curl https://dl.k8s.io/release/v1.35.1/bin/linux/amd64/kubectl -o kubectl
curl https://dl.k8s.io/release/v1.35.1/bin/linux/amd64/kubeadm -o kubeadm
curl https://dl.k8s.io/release/v1.35.1/bin/linux/amd64/kubelet -o kubelet
curl https://dl.k8s.io/release/v1.35.1/bin/linux/amd64/kube-proxy -o kube-proxy 
```


Validando o sha512sum:
```
sha512sum kubectl
sha512sum kubeadm
sha512sum kubelet
sha512sum kube-proxy

sha512sum /opt/course/5/q2/kubectl 
sha512sum /opt/course/5/q2/kubelet
sha512sum /opt/course/5/q2/kubeadm 
sha512sum /opt/course/5/q2/kube-proxy 
```

Depois mover os errados:
```
mv /opt/course/5/q2/kubectl /opt/course/5/q2/quarentena/
mv /opt/course/5/q2/kubelet /opt/course/5/q2/quarentena/
```