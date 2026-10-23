## Resposta

Comandos:
```
cat /etc/kubernetes/etcd/ec.yaml
vi /etc/kubernetes/etcd/ec.yaml
cp /etc/kubernetes/manifests/kube-apiserver.yaml .
vi /etc/kubernetes/manifests/kube-apiserver.yaml 
vi /etc/kubernetes/etcd/ec.yaml
vi /etc/kubernetes/manifests/kube-apiserver.yaml 
crictl ps -a | grep kube-api
crictl ps -a 
crictl ps -a | grep kube-api
k get secrets 
k get secrets  -A
k get secrets  -A -o yaml
k get secrets  -A -o yaml | k replace -f -
k get secrets -o yaml
k get secrets -o yaml -n bank
ETCDCTL_API=3 etcdctl    --cacert=/etc/kubernetes/pki/etcd/ca.crt      --cert=/etc/kubernetes/pki/etcd/server.crt    --key=/etc/kubernetes/pki/etcd/server.key     get /registry/secrets/bank/bank-creds | hexdump -C
ETCDCTL_API=3 etcdctl    --cacert=/etc/kubernetes/pki/etcd/ca.crt      --cert=/etc/kubernetes/pki/etcd/server.crt    --key=/etc/kubernetes/pki/etcd/server.key     get /registry/secrets/bank/bank-creds 
vi /etc/kubernetes/etcd/ec.yaml
crictl ps -a
crictl ps -a | grep kube-api
crictl stop 963230630d2c8
crictl ps -a | grep kube-api
crictl rm 963230630d2c8
crictl ps -a | grep kube-api
k get secrets  -A -o yaml | k replace -f -
ETCDCTL_API=3 etcdctl    --cacert=/etc/kubernetes/pki/etcd/ca.crt      --cert=/etc/kubernetes/pki/etcd/server.crt    --key=/etc/kubernetes/pki/etcd/server.key     get /registry/secrets/bank/bank-creds 
ETCDCTL_API=3 etcdctl    --cacert=/etc/kubernetes/pki/etcd/ca.crt      --cert=/etc/kubernetes/pki/etcd/server.crt    --key=/etc/kubernetes/pki/etcd/server.key     get /registry/secrets/bank/bank-creds  > /opt/course/15/q3/etcd-bank-creds.txt
k get secrets -n bank 
k get secrets -n bank -o yaml
./verify.sh 
```
  
cat /etc/kubernetes/etcd/ec.yaml
```
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: x0fQA8S5pBVqNEyuX9lUa0tCxMnpnWmSN4PwN0auBbE=
            - name: key2
              secret: pldKqaZa1GfbBMj/z+AlyV8ppvnHR+xbmFYHdKLOj8A=
      - identity: {}
```