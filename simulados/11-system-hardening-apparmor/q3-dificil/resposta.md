k edit node node01

security=apparmor

apparmor

 git clone https://github.com/LuizFelipeCibulski/cks.git
    2  cd cks/simulados/11-system-hardening-apparmor/q3-dificil/
    3  ls
    4  ./setup.sh 
    5  k edit nodes node01 
    6  apparmor_parser -r /opt/course/11/q3/k8s-deny-uploads
    7  apparmor_parser -r /opt/course/11/q3/k8s-deny-uploads --help
    8  apparmor_parser -r /opt/course/11/q3/k8s-deny-uploads --help | grep node
    9  cat /opt/course/11/q3/k8s-deny-uploads
   10  k get deployments.apps -n apparmor-q3 uploader 
   11  k get deployments.apps -n apparmor-q3 uploader -o yaml > bkp.yaml
   12  k edit deployments.apps -n apparmor-q3 uploader 
   13  k get deployments.apps -n apparmor-q3 uploader 
   14  k rollout restart deployment -n apparmor-q3 uploader 
   15  k get deployments.apps -n apparmor-q3 uploader 
   16  k get po -n apparmor-q3 
   17  k describe po -n apparmor-q3 uploader-67f777ffdb-t5c4s
   18  apparmor_parser -r /opt/course/11/q3/k8s-deny-uploads
   19  k get po -n apparmor-q3 
   20  k rollout restart deployment -n apparmor-q3 uploader 
   21  k get po -n apparmor-q3 
   22  k describe po -n apparmor-q3 uploader-6d8df7c7b6-5qqtw
   23  k get po -n apparmor-q3 -o wide
   24  cat /opt/course/11/q3/k8s-deny-uploads
   25  k get po -n apparmor-q3 
   26  k delete po -n apparmor-q3 *
   27  k delete po -n apparmor-q3 uploader-67f777ffdb-t5c4s uploader-69488c567f-vtbfc uploader-6d8df7c7b6-5qqtw
   28  k get po -n apparmor-q3 
   29  k edit deployments.apps -n apparmor-q3 uploader 
   30  k rollout restart deployment -n apparmor-q3 uploader 
   31  k get po -n apparmor-q3 
   32  k exec -it -n apparmor-q3 uploader-56dbdd4cf9-hgq9k -- touch /uploads/test
   33  k exec -it -n apparmor-q3 uploader-56dbdd4cf9-hgq9k -- touch /uploads/test > /opt/course/11/q3/write-test.txt
   34  cat /opt/course/11/q3/write-test.txt
   35  ./verify.sh 
   36  history 

NODE 01

 1  apparmor_status | grep k8s-den
    2  apparmor_status 
    3  cat /opt/course/11/q3/k8s-deny-uploads | grep k8s-deny-uploads
    4  cat /sys/kernel/security/apparmor/profiles | grep k8s-deny-uploads
    5  vi k8s-deny-uploads
    6  apparmor_parser -r k8s-deny-uploads 
    7  cat /sys/kernel/security/apparmor/profiles | grep k8s-deny-uploads
    8  systemctl restart apparmor.service 
    9  cat /sys/kernel/security/apparmor/profiles | grep k8s-deny-uploads
   10  cat /sys/module/apparmor/parameters/enabled
   11  cat /sys/kernel/security/apparmor/profiles | grep k8s-deny-uploads 
   12  apparmor_parser k8s-deny-uploads 
   13  apparmor_status 
   14  systemctl restart apparmor.service 
   15  cat /sys/kernel/security/apparmor/profiles | grep k8s-deny-uploads 
   16  aa-status
   17  cat /sys/kernel/security/apparmor/profiles
   18  cat /sys/kernel/security/apparmor/profiles | grep k8s-deny-uploads
   19  cat /sys/kernel/security/apparmor/profiles
   20  systemctl status apparmor.service 
   21  aa-status
   22  lls /etc/apparmor.d
   23  ls /etc/apparmor.d
   24  ls /etc/apparmor.d/local/
   25  cp k8s-deny-uploads /etc/apparmor.d/local/
   26  cp /etc/apparmor.d/local/k8s-deny-uploads /etc/apparmor.d/k8s-deny-uploads
   27  history