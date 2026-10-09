## Resposta


Validando os já instalados na máquina:
```
sha512sum /usr/bin/kubelet
2434f4822134cf810699a745ccb5cec3f0d2d366239a3776c585081c6247c66e1b8c373d01b76487f608a61ee66272d38cfb86d55674d60be5e4098f548cf6bf  /usr/bin/kubelet

sha512sum /usr/bin/kubectl 
a46767e161e0e764bb3295d556b36056b1dd8230dbb5286dc2f6b1587dd709ed6935c0a8433dd57e9b4673a2461dcbfedd99ef7388d5cd0cf7bca285ea6a28ba  /usr/bin/kubectl
```

Download do site oficial:
```
sudo curl -L --remote-name-all https://dl.k8s.io/release/v1.35.1/bin/linux/amd/{kubelet,kubectl}
```

validando o kube-apiserver:
```
ps -aux | grep kube-apiserver

cd /proc/PID

ls -lha

sha512sum exe

RESULTADO DO SHA

```