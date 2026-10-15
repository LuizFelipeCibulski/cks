## Resposta



Yamls alterado
```
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: logger
  name: logger
  namespace: immutable
spec:
  progressDeadlineSeconds: 600
  replicas: 1
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
        - mkdir -p /app/logs; while true; do echo "$(date) request processed" >> /app/logs/app.log;
          sleep 5; done
        image: busybox:1.36
        imagePullPolicy: IfNotPresent
        name: logger
        resources: {}
        securityContext:
          readOnlyRootFilesystem: true
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        volumeMounts:
        - mountPath: /app/logs
          name: logs
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
      volumes:
      - emptyDir:
          sizeLimit: 50Mi
        name: logs
```