Check the kubelet binary hash

Download the kubelet binary in the same version as the installed one.

kubelet --version

wget https://dl.k8s.io/v1.35.1/kubernetes-server-linux-amd64.tar.gz

Instalado no cluster:
whereis kubelet:
/usr/bin/kubelet
1bb50fe19dc394df46f4da06a12a70256a7ad598e809aae2c3af3a03e6b655f1

Download:

tar -zxf pacote
sha256sum kubernetes/server/bin/kubelet
e7343310e03ff0d424df4397bdfa4468947d6d1f0f93dac586c1e8d6e4086d5d


https://kubernetes.io/releases/download/