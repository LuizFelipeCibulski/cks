## Resposta

Yamls
```
cat /opt/course/18/q2/Dockerfile 
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y curl --no-install-recommends
RUN rm -rf /bin/bash 
RUN rm -rf /var/lib/apt/lists
RUN useradd app --uid 10001 --no-create-home --shell /usr/sbin/nologin
USER 10001
CMD ["sh", "-c", "curl -s --head \"$URL\" -H \"Authorization: Bearer $API_TOKEN\""]
```