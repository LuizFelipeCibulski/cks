Create workloads with readonly root filesystems

apiVersion: v1
kind: Pod
metadata:
  labels:
    run: pod-ro
  name: pod-ro
  namespace: sun
spec:
  containers:
  - image: busybox:1.32.0
    name: pod-ro
    command: ["sleep", "1d"]
    securityContext:
      readOnlyRootFilesystem: true
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}

---


read only with emptydir

apiVersion: v1
items:
- apiVersion: apps/v1
  kind: Deployment
  metadata:
    annotations:
      deployment.kubernetes.io/revision: "5"
    creationTimestamp: "2026-10-06T18:11:58Z"
    generation: 5
    labels:
      app: web4.0
    name: web4.0
    namespace: moon
    resourceVersion: "7124"
    uid: 177e103d-871f-4c7b-a673-0e58a2439a17
  spec:
    progressDeadlineSeconds: 600
    replicas: 2
    revisionHistoryLimit: 10
    selector:
      matchLabels:
        app: web4.0
    strategy:
      rollingUpdate:
        maxSurge: 25%
        maxUnavailable: 25%
      type: RollingUpdate
    template:
      metadata:
        labels:
          app: web4.0
      spec:
        containers:
        - command:
          - sh
          - -c
          - date > /etc/date.log && sleep 1d
          image: busybox:1.32.0
          imagePullPolicy: IfNotPresent
          name: container
          resources: {}
          securityContext:
            readOnlyRootFilesystem: true
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          volumeMounts:
          - mountPath: /etc
            name: ro
        dnsPolicy: ClusterFirst
        restartPolicy: Always
        schedulerName: default-scheduler
        securityContext: {}
        terminationGracePeriodSeconds: 30
        volumes:
        - emptyDir:
            sizeLimit: 500Mi
          name: ro
  status:
    availableReplicas: 2
    conditions:
    - lastTransitionTime: "2026-10-06T18:24:52Z"
      lastUpdateTime: "2026-10-06T18:24:52Z"
      message: Deployment has minimum availability.
      reason: MinimumReplicasAvailable
      status: "True"
      type: Available
    - lastTransitionTime: "2026-10-06T18:11:58Z"
      lastUpdateTime: "2026-10-06T18:24:52Z"
      message: ReplicaSet "web4.0-7f87d49475" has successfully progressed.
      reason: NewReplicaSetAvailable
      status: "True"
      type: Progressing
    observedGeneration: 5
    readyReplicas: 2
    replicas: 2
    terminatingReplicas: 0
    updatedReplicas: 2
kind: List
metadata:
  resourceVersion: ""