## Resposta


```
cat /etc/kubernetes/audit/policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
  - "RequestReceived"
rules:

  - level: Metadata
    resources:
    - group: "" # core API group
      resources: ["secrets"]

  - level: None
    verbs: ["get", "list", "watch"]

  - level: Metadata
```

