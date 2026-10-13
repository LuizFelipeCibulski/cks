## Resposta
apps-prod
```
pod-security.kubernetes.io/enforce-version: v1.34
pod-security.kubernetes.io/enforce: restricted

pod-security.kubernetes.io/warn-version: latest
pod-security.kubernetes.io/warn: restricted

pod-security.kubernetes.io/audit-version: latest
pod-security.kubernetes.io/audit: restricted
```

apps-dev
```
pod-security.kubernetes.io/enforce-version: latest
pod-security.kubernetes.io/enforce: baseline

pod-security.kubernetes.io/warn-version: latest
pod-security.kubernetes.io/warn: restricted
```

