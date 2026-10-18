## Resposta

Comandos
```
k get secrets -n legacy 
k get secrets -n legacy -o yaml 
k get secrets -n legacy -o yaml db-auth
echo "TDNnNGN5LUFkbSFuLTIwMTk=" | base64 -d
cat /opt/course/15/q2/admin-password.txt
mkdir /opt/course/15/q2
vi /opt/course/15/q2/admin-password.txt
k get po -n monitoring agent 
k exec -it -n monitoring agent -- sh
k exec -it -n monitoring agent -- cat /var/run/secrets/kubernetes.io/serviceaccount/token
vi /opt/course/15/q2/sa-token.txt
k get po -n monitoring agent 
k get po -n monitoring agent  -o yaml
k get secrets -n monitoring mon-store-7f3a
k get secrets -n monitoring mon-store-7f3a -o yaml
echo "mon-store-7f3a:" > /opt/course/15/q2/db-pass.txt
echo "UHIwbS1TdDByMyM0Mg==" | base64 -d
vi /opt/course/15/q2/db-pass.txt
./verify.sh 
```