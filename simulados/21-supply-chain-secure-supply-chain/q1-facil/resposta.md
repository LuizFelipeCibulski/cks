## Resposta

Comandos
```
ps aux | grep log-shipper
strace -p 8980
echo "openat" > /opt/course/22/q1/syscall.txt
echo "log-shipper" > /opt/course/22/q1/name.txt
echo "8980" > /opt/course/22/q1/pid.txt
kill -9 8980
rm -rf /usr/local/bin/log-shipper 
```