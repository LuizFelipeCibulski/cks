Cluster Setup - Secure Ingress

expose deployments:
k expose deployment -n world europe --port 80 
k expose deployment -n world asia --port 80 

ingress:

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: world
  namespace: world
spec:
  ingressClassName: nginx
  rules:
  - host: world.universe.mine
    http:
      paths:
      - path: /europe
        pathType: Prefix
        backend:
          service:
            name: europe
            port:
              number: 80
      - path: /asia
        pathType: Prefix
        backend:
          service:
            name: asia
            port:
              number: 80



https://kubernetes.io/docs/concepts/services-networking/ingress/