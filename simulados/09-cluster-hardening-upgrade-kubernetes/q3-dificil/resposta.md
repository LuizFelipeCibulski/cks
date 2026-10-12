## Resposta

https://v1-36.docs.kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/

```
sudo apt update
sudo apt-cache madison kubeadm
```

```
sudo apt-mark unhold kubeadm && \
sudo apt-get update && sudo apt-get install -y kubeadm='1.36.5-1.1' && \
sudo apt-mark hold kubeadm
```

```
kubeadm version
```

```
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.36.x
```

Para nodes: 
```
sudo kubeadm upgrade node
```

```
kubectl drain NODE --ignore-daemonsets
```

```
sudo apt-mark unhold kubelet kubectl && \
sudo apt-get update && sudo apt-get install -y kubelet='1.36.5-1.1' kubectl='1.36.5-1.1' && \
sudo apt-mark hold kubelet kubectl
```

```
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

```
kubectl uncordon NODE
```