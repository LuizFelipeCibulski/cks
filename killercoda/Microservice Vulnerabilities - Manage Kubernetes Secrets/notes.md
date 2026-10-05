Create secrets and access these in pods


k create secret generic holy --from-literal=creditcard=1111222233334444

apiVersion: v1
kind: Pod
metadata:
  labels:
    run: pod1
  name: pod1
spec:
  volumes:
    - name: diver
      secret:
        secretName: diver
  containers:
  - image: nginx
    name: pod1
    env:
    - name: HOLY
      valueFrom:
        secretKeyRef:
          name: holy
          key: creditcard
    volumeMounts:
      - name: diver
        readOnly: true
        mountPath: "/etc/diver"
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}

---

Read and decode secrets in different namespaces

k get secrets -n NS SECRETNAME -o yaml | grep data

echo -n "VALORDODATA" | base64 -d

---

Create a Pod with ServiceAccount that uses Secrets

k create sa secret-manager -n ns-secure

k create secret -n ns-secure generic sec-a1 --from-literal=ke
y1=123

k create secret -n ns-secure generic sec-a2 --from-file=/etc/hosts

apiVersion: v1
kind: Pod
metadata:
  labels:
    run: secret-manager
  name: secret-manager
  namespace: ns-secure
spec:
  serviceAccountName: secret-manager
  volumes:
    - name: seca2
      secret:
        secretName: sec-a2
  containers:
  - image: httpd:alpine
    name: secret-manager
    env:
    - name: SEC_A1
      valueFrom:
        secretKeyRef:
          name: sec-a1
          key: key1
    volumeMounts:
       - name: seca2
         readOnly: true
         mountPath: "/etc/sec-a2"
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}

https://kubernetes.io/docs/concepts/configuration/secret/


---
Enable ETCD encryption and encrypt existing secrets


---
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
      - configmaps
    providers:
      - aesgcm:
          keys:
            - name: key1
              # See the following text for more details about the secret value
              secret: dGhpcy1pcy12ZXJ5LXNlYw== 
      - identity: {} # this fallback allows reading unencrypted secrets;
                     # for example, during initial migration

k get secrets -n three -oyaml | k replace -f -

https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/