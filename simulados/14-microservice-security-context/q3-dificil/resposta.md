## Respostas

```
k get deployments.apps -n fin-a 
NAME            READY   UP-TO-DATE   AVAILABLE   AGE
audit-shipper   1/1     1            1           34s     Não ok hostPID: true
ledger          1/1     1            1           34s     Não ok privileged: true
web             1/1     1            1           34s     FALTA ADICIONAR O USER


k get deployments.apps -n fin-b 
NAME       READY   UP-TO-DATE   AVAILABLE   AGE
batch      1/1     1            1           3m30s  RODANDO COM USER 0
cache      1/1     1            1           3m30s  HOSTNETWORK
reporter   1/1     1            1           3m30s  SÒ TROCAR O USER


k get deployments.apps -n fin-c 
NAME          READY   UP-TO-DATE   AVAILABLE   AGE
api           1/1     1            1           6m55s  TROCAR O USER
sidecar-app   1/1     1            1           6m55s  não ok privileged: true

metrics  ADICIONAR USER
```


```
echo "fin-a/audit-shipper" > /opt/course/14/q3/violations.txt
echo "fin-a/ledger" >> /opt/course/14/q3/violations.txt
echo "fin-b/batch" >> /opt/course/14/q3/violations.txt
echo "fin-b/cache" >> /opt/course/14/q3/violations.txt
echo "fin-c/sidecar-app" >> /opt/course/14/q3/violations.txt
echo "fin-c/metrics" >> /opt/course/14/q3/violations.txt
```