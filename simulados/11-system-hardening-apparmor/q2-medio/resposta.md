## Resposta

```
apparmor_parser -r /etc/apparmor.d/k8s-nginx-ro 
```
```
cat /sys/kernel/security/apparmor/profiles | grep k8s* > /opt/course/11/q2/enforced.txt
```
```
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "4"
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"apps/v1","kind":"Deployment","metadata":{"annotations":{},"name":"web","namespace":"apparmor-q2"},"spec":{"replicas":2,"selector":{"matchLabels":{"app":"web"}},"template":{"metadata":{"labels":{"app":"web"}},"spec":{"containers":[{"image":"nginx:1.27-alpine","name":"nginx","ports":[{"containerPort":80}]},{"command":["sh","-c","while true; do date; sleep 10; done"],"image":"busybox:1.36","name":"logger"}],"nodeSelector":{"kubernetes.io/hostname":"controlplane"},"tolerations":[{"effect":"NoSchedule","key":"node-role.kubernetes.io/control-plane","operator":"Exists"}]}}}}
  creationTimestamp: "2026-10-12T16:30:40Z"
  generation: 4
  name: web
  namespace: apparmor-q2
  resourceVersion: "10521"
  uid: 3f8bfc0d-618a-4fa7-b8c2-acb20debb1e6
spec:
  progressDeadlineSeconds: 600
  replicas: 2
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: web
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - image: nginx:1.27-alpine
        imagePullPolicy: IfNotPresent
        name: nginx
        ports:
        - containerPort: 80
          protocol: TCP
        resources: {}
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      - command:
        - sh
        - -c
        - while true; do date; sleep 10; done
        image: busybox:1.36
        imagePullPolicy: IfNotPresent
        name: logger
        resources: {}
        securityContext:
          appArmorProfile:
            type: RuntimeDefault
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      dnsPolicy: ClusterFirst
      nodeSelector:
        kubernetes.io/hostname: controlplane
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext:
        appArmorProfile:
          localhostProfile: k8s-nginx-ro
          type: Localhost
      terminationGracePeriodSeconds: 30
      tolerations:
      - effect: NoSchedule
        key: node-role.kubernetes.io/control-plane
        operator: Exists
status:
  availableReplicas: 2
  conditions:
  - lastTransitionTime: "2026-10-12T16:30:51Z"
    lastUpdateTime: "2026-10-12T16:30:51Z"
    message: Deployment has minimum availability.
    reason: MinimumReplicasAvailable
    status: "True"
    type: Available
  - lastTransitionTime: "2026-10-12T16:30:40Z"
    lastUpdateTime: "2026-10-12T16:44:43Z"
    message: ReplicaSet "web-8869b75df" has successfully progressed.
    reason: NewReplicaSetAvailable
    status: "True"
    type: Progressing
  observedGeneration: 4
  readyReplicas: 2
  replicas: 2
  terminatingReplicas: 0
  updatedReplicas: 2
```