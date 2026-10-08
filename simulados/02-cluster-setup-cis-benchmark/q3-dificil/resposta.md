## Resposta

Rodar o kube-bench no node
```
mkdir -p /opt/course/02/q3
kube-bench run --targets node > /opt/course/02/q3/kube-bench-node-before.txt
grep FAIL /opt/course/02/q3/kube-bench-node-before.txt
```

Descobrir de onde vem os parametros de configuração
```
systemctl cat kubelet
```

Ponto importante a se notar: Flags de linha de comando têm precedência sobre o arquivo de config, sendo assim mesmo corrigindo o arquivo de configuração config.yaml o parametro --anonymous-auth=true que esta presente em /etc/default/kubelet vai ser mantido.

vim /var/lib/kubelet/config.yaml
```
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
authentication:
  anonymous:
    enabled: false          # era true
  webhook:
    cacheTTL: 0s
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook             # era AlwaysAllow
  webhook:
    cacheAuthorizedTTL: 0s
    cacheUnauthorizedTTL: 0s
...
readOnlyPort: 0             # era 10255 (ou apague a linha: o padrão no config file é 0)
```

E dentro do arquivo vim /etc/default/kubelet remover a tag --anonymous-auth=false

Apos isso reiniciar o serviço: 
```
systemctl daemon-reload
systemctl restart kubelet
systemctl status kubelet
```

Permissão de diretorios
```
chmod 600 /var/lib/kubelet/config.yaml /etc/kubernetes/kubelet.conf
chown root:root /var/lib/kubelet/config.yaml /etc/kubernetes/kubelet.conf
```

Configuração do etcd /etc/kubernetes/manifests/etcd.yaml
```
    - --client-cert-auth=true          # era false
```

no arquivo de manifesto do kube-controller-manager
```
- --use-service-account-credentials=true 
```

Validação do kube-bench depois: 

```
kubectl -n kube-system get pod
kube-bench run --targets node > /opt/course/02/q3/kube-bench-node-after.txt
grep -E 'anonymous|authorization-mode|read-only|permissions' /opt/course/02/q3/kube-bench-node-after.txt
kube-bench run --targets etcd | grep client-cert-auth
```