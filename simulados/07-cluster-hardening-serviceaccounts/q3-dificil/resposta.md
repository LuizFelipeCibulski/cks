## Resposta
Criar SA
```
k create sa pod-lister-sa -n observer 
k edit sa -n observer pod-lister-sa 
automountServiceAccountToken: false
```
Criar Role e RoleBinding
```
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: observer
  name: pod-list
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-lister-sa-pod-list
  namespace: observer
subjects:
- kind: ServiceAccount
  name:  pod-lister-sa
  namespace: observer
roleRef:
  kind: Role 
  name: pod-list
  apiGroup: rbac.authorization.k8s.io
```
Editar SA default
```
k edit sa -n observer default
automountServiceAccountToken: false
k delete rolebindings.rbac.authorization.k8s.io -n observer default-edit
```

Mudar configuração no pod:
```

  serviceAccountName: pod-lister-sa

  volumes:
  - name: api-token
    projected:
      sources:
      - serviceAccountToken:
          path: token
          audience: https://kubernetes.default.svc.cluster.local
          expirationSeconds: 3600
      - configMap:
          name: kube-root-ca.crt
          items:
          - key: ca.crt
            path: ca.crt
```