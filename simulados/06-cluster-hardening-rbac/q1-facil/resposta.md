## Resposta 

Yamls de resposta: 
```
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: finance
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: report-bot-pod-reader
  namespace: finance
subjects:
- kind: ServiceAccount
  name: report-bot
  namespace: finance
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
---
```