## Resposta

```
k get runtimeclasses.node.k8s.io -A
NAME             HANDLER     AGE
gvisor           gvisor      17m
kata             kata-qemu   17m
secure-runtime   runsc       17m
cat /etc/containerd/config.toml 
echo "secure-runtime" > /opt/course/16/q2/runtimeclass.txt


k edit deployments.apps -n untrusted
runtimeClassName: secure-runtime


k exec -it -n untrusted scanner-756bf5b5cd-656gv -- dmesg > /opt/course/16/q2/dmesg.txt
```