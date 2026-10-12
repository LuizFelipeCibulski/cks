## Resposta


Atualização dos pacotes no node:
```
sudo apt-mark unhold kubeadm kubectl && \
sudo apt-get update && sudo apt-get install -y kubeadm='1.35.1-1.1' kubectl='1.35.1-1.1' && \
sudo apt-mark hold kubeadm kubectl
```

Upgrade kubeadm:
```
sudo kubeadm upgrade node
```

Removendo pods do node:
```
kubectl drain node01 --ignore-daemonsets
```

Atualizando o kubelet:
```
sudo apt-mark unhold kubelet && \
sudo apt-get update && sudo apt-get install -y kubelet='1.35.1-1.1' && \
sudo apt-mark hold kubelet
```

Restart nos serviços:
```
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

Colocando node online novamente:
```
kubectl uncordon node01
```

Resultado:
```
k get nodes
NAME           STATUS   ROLES           AGE     VERSION
controlplane   Ready    control-plane   6d23h   v1.35.1
node01         Ready    <none>          6d23h   v1.35.1
```