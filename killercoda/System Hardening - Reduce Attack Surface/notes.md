Find process listening on port and close it

netstat -atp | grep 1234
tcp        0      0 0.0.0.0:1234            0.0.0.0:*               LISTEN      7074/app1  

-p, --programs           display PID/Program name for sockets

ps aux | grep 7074
root        7074  0.0  0.0   3460  2296 ?        S    14:08   0:00 /bin/app1 -l -v -p 1234

kill -9 7074
rm -rf /bin/app1 

----

Remove and stop different services

Your team has decided to use kube-bench via a DaemonSet instead of installing via package manager.
Go ahead and remove the kube-bench package using the default package manager.

 apt remove --purge kube-bench 
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following packages will be REMOVED:
  kube-bench*
0 upgraded, 0 newly installed, 1 to remove and 3 not upgraded.
After this operation, 24.5 MB disk space will be freed.
Do you want to continue? [Y/n] Y
(Reading database ... 177868 files and directories currently installed.)
Removing kube-bench (0.6.5) ...
dpkg: warning: while removing kube-bench, directory '/usr/local/bin' not empty so not removed


The package vsftpd has been installed.

Don't uninstall it, just stop the service.
systemctl stop vsftpd
