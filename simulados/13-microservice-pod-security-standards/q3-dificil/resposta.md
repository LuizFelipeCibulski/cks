
pod-security.kubernetes.io/enforce: restricted
pod-security.kubernetes.io/enforce-version: latest


Warning: would violate PodSecurity "restricted:latest": privileged (container "init-config" must not set securityContext.privileged=true), allowPrivilegeEscalation != false (containers "init-config", "api" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (containers "init-config", "api" must set securityContext.capabilities.drop=["ALL"]), restricted volume types (volume "logs" uses restricted volume type "hostPath"), runAsNonRoot != true (pod or containers "init-config", "api" must set securityContext.runAsNonRoot=true), runAsUser=0 (container "api" must not set runAsUser=0), seccompProfile (pod or containers "init-config", "api" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")"

pod-security.kubernetes.io/enforce: restricted
pod-security.kubernetes.io/enforce-version: latest

pod-security.kubernetes.io/audit: restricted
pod-security.kubernetes.io/audit-version: latest

pod-security.kubernetes.io/warn: restricted
pod-security.kubernetes.io/warn-version: latest


apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: PodSecurity
  configuration:
    apiVersion: pod-security.admission.config.k8s.io/v1
    kind: PodSecurityConfiguration
    defaults:
      enforce: "privileged"
      enforce-version: "latest"
      audit: "restricted"
      audit-version: "latest"
      warn: "baseline"
      warn-version: "latest"
    exemptions:
      # Array of authenticated usernames to exempt.
      usernames: []
      # Array of runtime class names to exempt.
      runtimeClasses: []
      # Array of namespaces to exempt.
      namespaces: ["kube-system", "legacy-batch"]

[ OK ] kube-apiserver respondendo
[ OK ] checkout: enforce=restricted
[ OK ] checkout: versão latest
[FAIL] /opt/course/13/q3/reason.txt deve conter a mensagem 'forbidden: violates PodSecurity "restricted:latest"...' do evento do ReplicaSet
[ OK ] checkout-api com 2/2 réplicas prontas e atualizadas
[ OK ] Nenhum Pod em checkout viola restricted
[ OK ] Sem hostPath
[ OK ] Volume 'logs' mantido (emptyDir)
[ OK ] mountPath /var/log/app mantido
[ OK ] Aplicação responde na porta 8080
[ OK ] Container api roda com UID 101 (não-root)
[ OK ] /etc/kubernetes/psa/podsecurity.yaml existe com AdmissionConfiguration/PodSecurity
[ OK ] kube-apiserver usa --admission-control-config-file=/etc/kubernetes/psa/podsecurity.yaml
[ OK ] legacy-batch isento: pod privilegiado aceito
[ OK ] legacy-batch manteve a label enforce=restricted
[FAIL] Defaults do PodSecurity não conferem (esperado aceitar com warning baseline:latest). Saída: Error from server (Forbidden): pods "p" is forbidden: violates PodSecurity "restricted:latest": host namespaces (hostPID=true), allowPrivilegeEscalation != false (container "p" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "p" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "p" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "p" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
[ OK ] /etc/kubernetes/manifests limpo