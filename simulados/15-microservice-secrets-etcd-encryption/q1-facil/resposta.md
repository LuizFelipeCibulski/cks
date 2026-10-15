## Resposta

```
k create secret generic db-credentials -n vault-app --from-literal=usern
ame=appuser --from-literal=password=Sup3r-S3cr3t!

apiVersion: v1
kind: Pod
metadata:
  labels:
    run: app
  name: app
  namespace: vault-app
spec:
  volumes:
    - name: secret
      secret:
        secretName: db-credentials
  containers:
  - image: busybox:1.36
    name: app
    resources: {}
    command: ['sh', '-c', 'sleep 1d']
    env:
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: username
    volumeMounts:
      - name: secret
        readOnly: true
        mountPath: "/etc/db-credentials"
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}

```
