## Resposta


```
systemctl status vsftpd.service 
systemctl stop vsftpd.service
systemctl disable vsftpd.service 
systemctl status tftpd-hpa.service
apt remove --purge tftpd-hpa

usermod -r -G sudo deploy-bot
usermod svc-backup -s /usr/sbin/nologin

cat /etc/sudoers.d/90-deploy-bot 
deploy-bot ALL=(ALL) NOPASSWD:ALL

rm -rf /etc/sudoers.d/90-deploy-bot
```