K8s components should be more conform with CIS rules


/etc/kubernetes/manifests/kube-apiserver.yaml

set --profiling to false


/etc/kubernetes/manifests/kube-controller-manager.yaml

set --profiling to false


1.1.19 Ensure that the Kubernetes PKI directory and file ownership is set to root:root (Automated)

chown -R root:root /etc/kubernetes/pki/