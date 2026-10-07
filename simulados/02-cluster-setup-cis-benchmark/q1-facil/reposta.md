## Resposta


Alterar no arquivo */etc/kubernetes/manifests/kube-controller-manager.yaml* o parametro profiling
```
    - --profiling=false
```

Alterar no arquivo */etc/kubernetes/manifests/kube-scheduler.yaml* o parametro profiling
```
- --profiling=false
```