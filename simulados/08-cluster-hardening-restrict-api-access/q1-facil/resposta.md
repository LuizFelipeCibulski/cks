## Resposta

```
k get clusterrolebindings.rbac.authorization.k8s.io -o yaml | grep system:anonymous
k get clusterrolebindings.rbac.authorization.k8s.io -o yaml | grep system:unauthenticated
```

```
echo "kubelet-debug-access" > /opt/course/8/q1/removidos.txt
echo "metrics-public-access" >> /opt/course/8/q1/removidos.txt
```

```
k delete clusterrolebindings.rbac.authorization.k8s.io kubelet-debug-access
k delete clusterrolebindings.rbac.authorization.k8s.io metrics-public-access
```