## Resposta

Validar o sha512sum: 
```
cat /opt/course/5/q1/sha512sums.txt
```

Validar os binarios:
```
sha512sum /opt/course/5/q1/kubeadm 
sha512sum /opt/course/5/q1/kubectl
sha512sum /opt/course/5/q1/kubelet
```

Remover o diferente: 
```
rm -rf /opt/course/5/q1/kubeadm
```