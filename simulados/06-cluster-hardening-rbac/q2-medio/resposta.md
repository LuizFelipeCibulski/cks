## Resposta


Yamls dos role:
```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: app-viewer
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "watch", "list"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "watch", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: jane-app-viewer
  namespace: team-a
subjects:
- kind: User
  name: jane
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: app-viewer
  apiGroup: rbac.authorization.k8s.io

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ci-app-viewer
  namespace: team-b
subjects:
- kind: ServiceAccount
  name: ci
  namespace: team-b
roleRef:
  kind: ClusterRole
  name: app-viewer
  apiGroup: rbac.authorization.k8s.io
```

Validando já existente:
```
k get rolebindings.rbac.authorization.k8s.io -n team-a  | grep legacy
legacy-access     ClusterRole/view         17m
root@controlplane:~/cks/simulados/06-cluster-hardening-rbac/q2-medio$ k describe rolebindings.rbac.authorization.k8s.io -n team-a legacy-access 
Name:         legacy-access
Labels:       <none>
Annotations:  <none>
Role:
  Kind:  ClusterRole
  Name:  view
Subjects:
  Kind            Name    Namespace
  ----            ----    ---------
  ServiceAccount  legacy  team-b
```