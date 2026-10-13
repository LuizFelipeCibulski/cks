## Resposta

vi /var/lib/kubelet/config.yaml
```
seccompDefault: true
```

/var/lib/kubelet/seccomp/profiles/no-mkdir.json
```
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "architectures": [
    "SCMP_ARCH_X86_64",
    "SCMP_ARCH_X86",
    "SCMP_ARCH_X32"
  ],
  "syscalls": [
    {
      "names": [
           "mkdir", 
           "mkdirat"
      ],
      "action": "SCMP_ACT_ERRNO"
    }
  ]
}
```

deployment
```
apiVersion: v1
items:
- apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: builder
    namespace: seccomp-q3
  spec:
    progressDeadlineSeconds: 600
    replicas: 2
    revisionHistoryLimit: 10
    selector:
      matchLabels:
        app: builder
    strategy:
      rollingUpdate:
        maxSurge: 25%
        maxUnavailable: 25%
      type: RollingUpdate
    template:
      metadata:
        annotations:
          kubectl.kubernetes.io/restartedAt: "2026-10-13T14:12:51Z"
        labels:
          app: builder
      spec:
        containers:
        - command:
          - sh
          - -c
          - sleep 1d
          image: busybox:1.36
          imagePullPolicy: IfNotPresent
          name: builder
          resources: {}
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
        dnsPolicy: ClusterFirst
        nodeSelector:
          kubernetes.io/hostname: node01
        restartPolicy: Always
        schedulerName: default-scheduler
        securityContext:
          seccompProfile:
            localhostProfile: profiles/no-mkdir.json
            type: Localhost
        terminationGracePeriodSeconds: 30
        tolerations:
        - effect: NoSchedule
          key: node-role.kubernetes.io/control-plane
          operator: Exists
```

```
k get po -n seccomp-q3 plain -o yaml > bkp.yaml
k delete po -n seccomp-q3 plain --force
k apply -d bkp.yaml
```