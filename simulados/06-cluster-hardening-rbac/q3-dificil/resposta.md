## Resposta 

openssl genrsa -out /opt/course/6/q3/dev-maria.key 2048

openssl req -new -key /opt/course/6/q3/dev-maria.key -out /opt/course/6/q3/dev-maria.csr -subj "/CN=dev-maria/O=developers" 

cat /opt/course/6/q3/dev-maria.csr | base64 | tr -d "\n"



cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: dev-maria
spec:
  request: 
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400  # one day
  usages:
  - client auth
EOF

kubectl get csr

kubectl certificate approve dev-maria

kubectl get csr dev-maria -o jsonpath='{.status.certificate}'| base64 -d > /opt/course/6/q3/dev-maria.crt

kubectl config set-credentials dev-maria --client-key=/opt/course/6/q3/dev-maria.key --client-certificate=/opt/course/6/q3/dev-maria.crt --embed-certs=true

kubectl config set-context dev-maria --cluster=kubernetes --user=dev-maria

kubectl --context dev-maria auth whoami

apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: project-x
  name: pod-developer
rules:
- apiGroups: [""] 
  resources: ["pods"]
  verbs: ["get", "list", "watch", "create", "delete"]
- apiGroups: [""] 
  resources: ["pods/log"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-maria-pod-developer
  namespace: project-x
subjects:
- kind: User
  name: dev-maria
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-developer
  apiGroup: rbac.authorization.k8s.io



