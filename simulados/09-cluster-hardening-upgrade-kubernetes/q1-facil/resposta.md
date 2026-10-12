## Resposta
```
# Pegar versão dos nodes
k get nodes -o wide

kubeadm upgrade plan > /opt/course/09/q1/plan.txt

apt-cache madison kubeadm

kubectl drain node01 --ignore-daemonsets --force --delete-emptydir-data
```