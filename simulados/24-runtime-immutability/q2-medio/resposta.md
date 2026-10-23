## Resposta

Yamls:
```
apiVersion: v1
items:
- apiVersion: apps/v1
  kind: Deployment
  metadata:
    labels:
      app: web
    name: web
    namespace: frontend
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
          securityContext:
            readOnlyRootFilesystem: true
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          volumeMounts:
          - mountPath: /usr/share/nginx/html
            name: html
          - mountPath: /var/cache/nginx/
            name: nginx-cache
          - mountPath: /run/
            name: nginx-run
        - command:
          - sh
          - -c
          - |
            while true; do
              echo "<h1>generated at $(date)</h1>" > /tmp/index.html.new
              cp /tmp/index.html.new /html/index.html
              sleep 10
            done
          image: busybox:1.36
          imagePullPolicy: IfNotPresent
          name: content
          resources: {}
          securityContext:
            readOnlyRootFilesystem: true
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          volumeMounts:
          - mountPath: /html
            name: html
          - mountPath: /tmp
            name: content-tmp
        dnsPolicy: ClusterFirst
        restartPolicy: Always
        schedulerName: default-scheduler
        securityContext: {}
        terminationGracePeriodSeconds: 30
        volumes:
        - emptyDir: {}
          name: html
        - emptyDir: {}
          name: nginx-cache
        - emptyDir: {}
          name: nginx-run
        - emptyDir: {}
          name: content-tmp
```