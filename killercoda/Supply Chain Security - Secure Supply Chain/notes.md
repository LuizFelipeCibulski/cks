Complete the ImagePolicyWebhook setup

An ImagePolicyWebhook setup has been half finished, complete it:

The configuration directory is at /etc/kubernetes/policywebhook with files like admission_config.json and kubeconf .

    Make sure admission_config.json points to correct kubeconfig
    Set the allowTTL to 100
    All Pod creation should be prevented if the external service is not reachable
    The external service will be reachable under https://localhost:1234 in the future. Configure the kubeconf accordingly. It doesn't exist yet so it shouldn't be able to create any Pods till then
    Register the correct admission plugin in the apiserver

{
   "apiVersion": "apiserver.config.k8s.io/v1",
   "kind": "AdmissionConfiguration",
   "plugins": [
      {
         "name": "ImagePolicyWebhook",
         "configuration": {
            "imagePolicy": {
               "kubeConfigFile": "/etc/kubernetes/policywebhook/kubeconf",
               "allowTTL": 100,
               "denyTTL": 50,
               "retryBackoff": 500,
               "defaultAllow": false
            }
         }
      }
   ]
}

cat /etc/kubernetes/policywebhook/kubeconf              
apiVersion: v1
kind: Config

# clusters refers to the remote service.
clusters:
- cluster:
    certificate-authority: /etc/kubernetes/policywebhook/external-cert.pem  # CA for verifying the remote service.
    server: https://localhost:1234                  # URL of remote service to query. Must use 'https'.
  name: image-checker

contexts:
- context:
    cluster: image-checker
    user: api-server
  name: image-checker
current-context: image-checker
preferences: {}

# users refers to the API server's webhook configuration.
users:
- name: api-server
  user:
    client-certificate: /etc/kubernetes/policywebhook/apiserver-client-cert.pem     # cert for the webhook admission controller to use
    client-key:  /etc/kubernetes/policywebhook/apiserver-client-key.pem             # key matching the cert

## APi server config:
    - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook
    - --admission-control-config-file=/etc/kubernetes/policywebhook/admission_config.json



---

Use image digests instead of tags

k run crazy-pod --image=nginx@sha256:eb05700fe7baa6890b74278e39b66b2ed1326831f9ec3ed4bdc6361a4ac2f333

para pegar o image digest é preciso dar um describe no pod que já está rodando com a imagem e pegar a image ID. 

