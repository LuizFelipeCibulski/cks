## Resposta

```
podman build -t app-q1:v1 /opt/course/18/q1/

podman run -d app-q1:v1 

podman exec -t 9c3a4084dfc6 ps aux > /opt/course/18/q1/ps.txt
```