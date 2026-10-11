## Resposta

Criar a serive account:
```
k create sa orders-web-sa -n orders 
```

Adicionar parametro serviceAccountName no deployment:
```
serviceAccountName: build-robot
automountServiceAccountToken: false
```

Editar o SA default na namespace orders:
```
automountServiceAccountToken: false
```

Create a token:
```
kubectl create token orders-ci -n orders --duration 1h 

echo TOKEN > /opt/course/7/q2/orders-ci.token
```