# Exemplo de como testar:


## Criação dos pods necessarios
```
k run frontend --image=nginx

k run backend --image=nginx

k expose po backend --port=80

k expose po frontend --port=80
```
Esses comandos vão criar os pods utilizando a imagem nginx e expor a porta 80.

Antes de aplicar as network policies, vamos testar a comunicação entre os pods

```
k exec -it frontend -- curl backend
k exec -it backend -- curl frontend
```

Podemos validar que esses comando vão retornar a página padrão do nginx.

Agora vamos aplicar a policy default-deny

```
k apply -f default-deny/default-deny.yaml
```

Agora podemos rodar novamente o comando curl entre os pods e validar que não teremos respostas, isso acontece pois a networkpolice definida no arquivo "default-deny.yaml" nega todo o trafego de entrada e saída da namespace default.

> Para podermos testar utilizando DNS, vamos deletar a network policy recem aplicada e utilizar a configuração presente no arquivo "default-deny-allow-dns.yaml", esse arquivo faz a liberação da porta 53 para consulta DNS.


