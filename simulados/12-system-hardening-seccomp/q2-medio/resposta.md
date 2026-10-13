##Resposta

```
cp /opt/course/12/q2/block-chmod.json /var/lib/kubelet/seccomp/profiles/
```

```
/opt/course/12/q2/pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: hardened
  namespace: seccomp-q2
spec:
  nodeSelector:
    kubernetes.io/hostname: controlplane
  tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/block-chmod.json
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
```

```
k exec -it -n seccomp-q2 hardened -- touch /tmp/secret
k exec -it -n seccomp-q2 hardened -- chmod 600 /tmp/secret > /opt/course/12/q2/chmod.txt
k exec -it -n seccomp-q2 hardened -- cat /proc/1/status | grep Seccomp
```