##Resposta

Comandos:
```
k get po -n team-alpha -o yaml | grep -C15 "privileged: true"  {debug-tools}
k get po -n team-beta -o yaml | grep -C20 "privileged: true" {bootstrap | }
k get po -n team-gamma -o yaml | grep -C15 "privileged: true" {sysctl-tuner}

echo "team-alpha/debug-tools" > /opt/course/14/q2/privileged-pods.txt
echo "team-beta/collector" >> /opt/course/14/q2/privileged-pods.txt
echo "team-beta/metrics-collector-6945c74bc-lprkd" >> /opt/course/14/q2/privileged-pods.txt
echo "team-beta/metrics-collector-6945c74bc-tbdct" >> /opt/course/14/q2/privileged-pods.txt
echo "team-gamma/bootstrap" >> /opt/course/14/q2/privileged-pods.txt

k delete po -n team-alpha debug-tools --force
k delete po -n team-gamma bootstrap --force
```