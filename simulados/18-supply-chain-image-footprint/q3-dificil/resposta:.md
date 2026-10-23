## Resposta:


Yamls /opt/course/18/q3/app/Dockerfile
```
FROM golang:1.23-alpine AS build
RUN apk add --no-cache bash curl git
WORKDIR /src
COPY . .
ENV GITHUB_TOKEN=ghp_Xk29fLq0aZr8PpT3vN7sWc1YhE5uJd4mB6oQ
RUN go build -o /usr/local/bin/payments .
EXPOSE 8080
CMD ["payments"]

FROM scratch
COPY --from=build /usr/local/bin/payments /usr/local/bin/payments
USER 1000
CMD ["/usr/local/bin/payments"]
```


```
 docker run -d -p 18080:8080 --name payments payments:v2
```