#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

D=/opt/course/6/q3
KC=$D/dev-maria.kubeconfig
CIR=system:serviceaccount:project-x:ci-runner

# 1. chave + CSR
for f in dev-maria.key dev-maria.csr dev-maria.crt dev-maria.kubeconfig; do
  [ -s "$D/$f" ] && ok "$f existe" || fail "$D/$f não existe"
done
if [ -s "$D/dev-maria.csr" ]; then
  SUBJ=$(openssl req -in "$D/dev-maria.csr" -noout -subject 2>/dev/null)
  echo "$SUBJ" | grep -Eq 'CN ?= ?dev-maria' && echo "$SUBJ" | grep -Eq 'O ?= ?developers' \
    && ok "CSR com CN=dev-maria e O=developers" || fail "Subject do CSR incorreto: $SUBJ"
fi
if [ -s "$D/dev-maria.key" ]; then
  BITS=$(openssl pkey -in "$D/dev-maria.key" -noout -text 2>/dev/null | grep -oE '[0-9]+ bit' | head -1)
  [ "$BITS" = "2048 bit" ] && ok "Chave RSA 2048" || fail "Chave não é RSA 2048 ($BITS)"
fi

# 2. CertificateSigningRequest
SIGNER=$(kubectl get csr dev-maria -o jsonpath='{.spec.signerName}' 2>/dev/null)
[ "$SIGNER" = "kubernetes.io/kube-apiserver-client" ] && ok "CSR dev-maria com signer correto" || fail "CSR dev-maria ausente ou signer incorreto ($SIGNER)"
kubectl get csr dev-maria -o jsonpath='{.spec.usages}' 2>/dev/null | grep -q 'client auth' && ok "CSR com usage client auth" || fail "CSR sem usage 'client auth'"
EXP=$(kubectl get csr dev-maria -o jsonpath='{.spec.expirationSeconds}' 2>/dev/null)
[ "$EXP" = "86400" ] && ok "CSR com expirationSeconds 86400" || fail "expirationSeconds do CSR incorreto ($EXP)"
kubectl get csr dev-maria -o jsonpath='{.status.conditions[*].type}' 2>/dev/null | grep -q Approved && ok "CSR aprovado" || fail "CSR não aprovado"

if [ -s "$D/dev-maria.crt" ]; then
  openssl verify -CAfile /etc/kubernetes/pki/ca.crt "$D/dev-maria.crt" >/dev/null 2>&1 \
    && ok "Certificado assinado pela CA do cluster" || fail "Certificado não é válido para a CA do cluster"
  P1=$(openssl x509 -in "$D/dev-maria.crt" -noout -pubkey 2>/dev/null | sha256sum)
  P2=$(openssl pkey -in "$D/dev-maria.key" -pubout 2>/dev/null | sha256sum)
  [ "$P1" = "$P2" ] && ok "Certificado corresponde à chave privada" || fail "Certificado não corresponde à chave"
fi

# 3. kubeconfig
CTX=$(kubectl config current-context --kubeconfig "$KC" 2>/dev/null)
[ "$CTX" = "dev-maria" ] && ok "current-context = dev-maria" || fail "current-context do kubeconfig incorreto ($CTX)"
WHO=$(kubectl --kubeconfig "$KC" auth whoami -o json 2>/dev/null | tr -d ' \n')
echo "$WHO" | grep -q '"username":"dev-maria"' && ok "kubeconfig autentica como dev-maria" || { fail "kubeconfig não autentica como dev-maria"; finish; }

# 4/5. permissões efetivas (via o próprio kubeconfig: inclui o grupo developers)
can() { [ "$(kubectl --kubeconfig "$KC" auth can-i "$@" 2>/dev/null)" = "yes" ]; }
for v in get list watch create delete; do
  can "$v" pods -n project-x && ok "dev-maria pode $v pods" || fail "dev-maria NÃO pode $v pods em project-x"
done
can get pods --subresource=log -n project-x && ok "dev-maria pode ler pods/log" || fail "dev-maria NÃO pode ler pods/log"

can create pods --subresource=exec -n project-x && fail "dev-maria pode usar pods/exec (excesso)" || ok "dev-maria sem pods/exec"
can create deployments.apps -n project-x && fail "dev-maria pode criar deployments (excesso)" || ok "dev-maria não cria deployments"
can get secrets -n project-x && fail "dev-maria pode ler secrets (excesso)" || ok "dev-maria não lê secrets"
can update pods -n project-x && fail "dev-maria pode atualizar pods (excesso)" || ok "dev-maria não atualiza pods"
can list pods -n default && fail "dev-maria acessa outros namespaces" || ok "dev-maria não acessa outros namespaces"
can get nodes && fail "dev-maria pode ler nodes" || ok "dev-maria não lê nodes"
can '*' '*' && fail "dev-maria ainda é cluster-admin" || ok "dev-maria não é cluster-admin"

kubectl -n project-x get role pod-developer >/dev/null 2>&1 && ok "Role pod-developer existe" || fail "Role pod-developer não existe"
REF=$(kubectl -n project-x get rolebinding dev-maria-pod-developer -o jsonpath='{.roleRef.kind}/{.roleRef.name}' 2>/dev/null)
[ "$REF" = "Role/pod-developer" ] && ok "RoleBinding dev-maria-pod-developer -> Role/pod-developer" || fail "RoleBinding dev-maria-pod-developer ausente/incorreta ($REF)"

kubectl get clusterrole cluster-admin edit view admin >/dev/null 2>&1 && ok "ClusterRoles padrão preservadas" || fail "Alguma ClusterRole padrão foi apagada"

# 6. ci-runner
cana() { [ "$(kubectl auth can-i "$@" 2>/dev/null)" = "yes" ]; }
cana list deployments.apps -n project-x --as "$CIR" && ok "ci-runner mantém leitura em project-x" || fail "ci-runner perdeu o view em project-x"
cana list secrets -n kube-system --as "$CIR" && fail "ci-runner ainda lê secrets em kube-system" || ok "ci-runner sem acesso a kube-system"
cana get nodes --as "$CIR" && fail "ci-runner ainda tem permissões cluster-wide" || ok "ci-runner sem permissões cluster-wide"
cana create deployments.apps -n project-x --as "$CIR" && fail "ci-runner pode criar deployments" || ok "ci-runner sem escrita em project-x"

finish
