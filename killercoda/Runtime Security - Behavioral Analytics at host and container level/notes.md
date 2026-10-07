Understand strace and use it to investigate the Apiserver


ps aux | grep kube-apiserver
strace -p 2162 -f -cw


---

Investigate and change a Falco Rule

k run pod --image=nginx:alpine,
k exec -it pod -- bash

2026-10-06T17:59:08.372015+00:00 controlplane falco: 17:59:08.370713347: Notice A shell was spawned in a container with an attached terminal | evt_type=execve user=root user_uid=0 user_loginuid=-1 process=sh proc_exepath=/bin/busybox parent=containerd-shim command=sh terminal=34816 exe_flags=EXE_WRITABLE|EXE_LOWER_LAYER container_id=bc738f9c8490 container_name=pod container_image_repository=docker.io/library/nginx container_image_tag=alpine k8s_pod_name=pod k8s_ns_name=default

 cat /etc/falco/falco_rules.local.yaml 
# Your custom rules!
- rule: Terminal shell in container
  desc: >
    A shell was used as the entrypoint/exec point into a container with an attached terminal. Parent process may have
    legitimately already exited and be null (read container_entrypoint macro). Common when using "kubectl exec" in Kubernetes.
    Correlate with k8saudit exec logs if possible to find user or serviceaccount token used (fuzzy correlation by namespace and pod name).
    Rather than considering it a standalone rule, it may be best used as generic auditing rule while examining other triggered
    rules in this container/tty.
  condition: >
    spawned_process
    and container
    and shell_procs
    and proc.tty != 0
    and container_entrypoint
    and not user_expected_terminal_shell_in_container_conditions
  output: NEW SHELL!!! user_id=%user.uid repo=%container.image.repository || A shell was spawned in a container with an attached terminal | evt_type=%evt.type user=%user.name user_uid=%user.uid user_loginuid=%user.loginuid process=%proc.name proc_exepath=%proc.exepath parent=%proc.pname command=%proc.cmdline terminal=%proc.tty exe_flags=%evt.arg.flags
  priority: NOTICE
  tags: [maturity_stable, container, shell, mitre_execution, T1059]


Response:
  2026-10-06T18:02:32.342099+00:00 controlplane falco: 18:02:32.340307704: Notice NEW SHELL!!! user_id=0 repo=docker.io/library/nginx || A shell was spawned in a container with an attached terminal | evt_type=execve user=root user_uid=0 user_loginuid=-1 process=sh proc_exepath=/bin/busybox parent=containerd-shim command=sh terminal=34816 exe_flags=EXE_WRITABLE|EXE_LOWER_LAYER container_id=bc738f9c8490 container_name=pod container_image_repository=docker.io/library/nginx container_image_tag=alpine k8s_pod_name=pod k8s_ns_name=default