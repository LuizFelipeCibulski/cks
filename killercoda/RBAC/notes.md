Create a RBAC scenario and control ServiceAccount permissions

create 
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pipeline
  namespace: ns1
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: view-ns1
subjects:
- kind: ServiceAccount
  name: pipeline
  namespace: ns1
roleRef:
  kind: ClusterRole #this must be Role or ClusterRole
  name: view # this must match the name of the Role or ClusterRole you wish to bind to
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deletedep-ns1
  namespace: ns1
subjects:
- kind: ServiceAccount
  name: pipeline
  namespace: ns1
roleRef:
  kind: ClusterRole #this must be Role or ClusterRole
  name: deletesa # this must match the name of the Role or ClusterRole you wish to bind to
  apiGroup: rbac.authorization.k8s.io


apiVersion: v1
kind: ServiceAccount
metadata:
  name: pipeline
  namespace: ns2
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: view-ns2
subjects:
- kind: ServiceAccount
  name: pipeline
  namespace: ns2
roleRef:
  kind: ClusterRole #this must be Role or ClusterRole
  name: view # this must match the name of the Role or ClusterRole you wish to bind to
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deletedep-ns1
  namespace: ns2
subjects:
- kind: ServiceAccount
  name: pipeline
  namespace: ns2
roleRef:
  kind: ClusterRole #this must be Role or ClusterRole
  name: deletesa # this must match the name of the Role or ClusterRole you wish to bind to
  apiGroup: rbac.authorization.k8s.io


kubectl create clusterrole deletesa  --verb=delete,create --resource=deployments

---

Create a RBAC scenario and control User permissions

1. User smoke should be allowed to create and delete Pods, Deployments and StatefulSets in Namespace applications.

k create role smoke -n applications --verb=create,delete --resource=pods,deployments,statefulsets

apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: smoke
  namespace: applications
subjects:
- kind: User
  name: smoke
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role #this must be Role or ClusterRole
  name: smoke # this must match the name of the Role or ClusterRole you wish to bind to
  apiGroup: rbac.authorization.k8s.io

kubectl create rolebinding smokeriding --clusterrole=view --user=smoke --namespace=applications

kubectl create rolebinding smokeriding --clusterrole=view --user=smoke --namespace=cilium-secrets

kubectl create rolebinding smokeriding --clusterrole=view --user=smoke --namespace=default

kubectl create rolebinding smokeriding --clusterrole=view --user=smoke --namespace=kube-node-lease

kubectl create rolebinding smokeriding --clusterrole=view --user=smoke --namespace=kube-public

kubectl create rolebinding smokeriding --clusterrole=view --user=smoke --namespace=local-path-storage

k create role smoke-secret -n applications --verb=list --resource=secret

kubectl create rolebinding smokeridingsecret --clusterrole=smoke-secret --user=smoke --namespace=applications

---
Create and manually sign a certificate to authenticate as user against K8s

Criando um novo user para acessar o kubernetes: 
Gerando a key com openssl:
openssl genrsa -out jim.key 2048

Request csr: 
openssl req -new -key jim.key -out jim.csr
openssl req -new -key myuser.key -out myuser.csr -subj "/CN=jim"

Criando um CertificateSigningRequest:
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: jim
spec:
  request: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURSBSRVFVRVNULS0tLS0KTUlJQ21EQ0NBWUFDQVFBd1V6RUxNQWtHQTFVRUJoTUNRVlV4RXpBUkJnTlZCQWdNQ2xOdmJXVXRVM1JoZEdVeApJVEFmQmdOVkJBb01HRWx1ZEdWeWJtVjBJRmRwWkdkcGRITWdVSFI1SUV4MFpERU1NQW9HQTFVRUF3d0RhbWx0Ck1JSUJJakFOQmdrcWhraUc5dzBCQVFFRkFBT0NBUThBTUlJQkNnS0NBUUVBeDZtZU1URUQ5NmRhRXZFN0piSUMKNGEzVWtyRWNBbDRVajVBTmY1U2lyeEMwQjhldmJCS2hxOWhLRjgvS1NGUk1yN1I5RHdJRUw2bDZkaFRWQnJRcgppazNVWGRRUUZTM2pkWGxpeEdlQU9hejZTTVFrYmQzS3NRYUdvWTFnczNOSXhBaVd1TG82NFp3a09yZDdQc0lECkh5bVJjV21rWVB1Qk9nMFhTRGVnVzhudnhTU215N294Z1F0TTZqMk1pZkM5V01nYWlLRW42MDNMSTN2OWR4VVAKSW1tYlB1d3RudDVpcWkybEVIVmJHUktBeHVWUmNpVmJWNStOTlRCQnZUZ2p2aS9HNTRXN3dBaWRRRjFvUHJaQgo5UFpaL25vUEl5WEtPV3c3ZFJOaTdrcnFrTGVsS01KMGRhZ3lJYmx2NTI1Slo1eWxjMlE1R1crbzNkVHNxZDFhCm9RSURBUUFCb0FBd0RRWUpLb1pJaHZjTkFRRUxCUUFEZ2dFQkFGU3hoVGx6NndzL2MweEVIVHFnbThoM1BBV28KWm9jRFN3alp1aXowY1U0VFBkMG9SVUNxWktIUkFtUUFrc3BkNzZRK25BZW8wNDRwcmJKRHRxQVV0bkd1QSttbwpEcDRIS3dXWlBCMjRjcEYzRkJqbUNBMWFqMzRXektHb0IxYmdnOHpoMXNRdWNIU3kwS21wbXYwUm0yelovMHp6Ck15VDJDc3U0NjNBc3pLWjg4Um5KMVdYNFlFdC9QaUtEZlozTmU4RGFObkF1bVZ0MkNzd2dRVnpSSktKNDBXMUwKcTFOTmgvZ0NvQTBkR1g1VEhaOUJ2MEx1Qkk5d1N4N01NVjlIVE9XNUR1dTliUmdxUU9KdmVZMTRJSWVtSU44SgpKZDdzTUZXTXZxbUJMYjFibHhNYk82TnlFN2JTNldQK29ONUpTd1hLVVBBcDZtbXpCcTlnVWM0R2pmbz0KLS0tLS1FTkQgQ0VSVElGSUNBVEUgUkVRVUVTVC0tLS0tCg== 
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400  # one day
  usages:
  - client auth

Conteúdo do request é o csr em base64: 
cat jim.csr | base64 | tr -d "\n"

Aprovar a requisição: 
kubectl get csr
kubectl certificate approve jim

Utilizando o certificado: 
kubectl get csr jim -o jsonpath='{.status.certificate}'| base64 -d > jim.crt

Adicionando o kubeconfig file:
kubectl config set-credentials jim --client-key=jim.key --client-certificate=jim.crt --embed-certs=true

Adicionando o contexto: 
kubectl config set-context jim --cluster=kubernetes --user=jim

https://kubernetes.io/docs/tasks/tls/certificate-issue-client-csr/

---