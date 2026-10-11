## Resposta

yamls:
```

apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend-sa
  namespace: payments
automountServiceAccountToken: false
---
apiVersion: v1
kind: Pod
metadata:
  name: backend
  namespace: payments
spec:
  serviceAccountName: backend-sa
  containers:
  - name: backend
    image: nginx:1.27-alpine
    ports:
    - containerPort: 80
```