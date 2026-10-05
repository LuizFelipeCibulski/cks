Create privileged workloads and understand what this means practically


apiVersion: v1
kind: Pod
metadata:
  labels:
    run: prime
  name: prime
spec:
  containers:
  - image: nginx:alpine
    name: prime
    resources: {}
    securityContext:
      privileged: true
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}

---


Set Privilege Escalation for Deployment

apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "1"
  creationTimestamp: "2026-10-01T13:05:30Z"
  generation: 1
  labels:
    app: logger
  name: logger
  namespace: default
  resourceVersion: "41020"
  uid: 4dc490cf-c8ac-4510-810f-41aa8f5798dd
spec:
  progressDeadlineSeconds: 600
  replicas: 3
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: logger
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: logger
    spec:
      containers:
      - command:
        - sh
        - -c
        - while true; do cat /proc/1/status | grep NoNewPrivs; sleep 1; done
        image: bash:5.0.18-alpine3.14
        imagePullPolicy: IfNotPresent
        name: httpd
        resources: {}
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        securityContext:
          allowPrivilegeEscalation: false
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 0


      https://blog.christophetd.fr/stop-worrying-about-allowprivilegeescalation/
      https://kubernetes.io/docs/tasks/configure-pod-container/security-context/