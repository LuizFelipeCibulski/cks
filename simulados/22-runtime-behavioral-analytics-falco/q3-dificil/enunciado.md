# Behavioral Analytics — Q3 (Difícil)

**Domínio:** Monitoring, Logging and Runtime Security (20%) — Perform behavioral analytics / Investigate and identify phases of attack
**Tempo sugerido:** ~12 min

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane (instala o Falco se necessário, ~2 min)
```

## Contexto

Um colega tentou criar uma regra customizada do Falco chamada `Write below etc in container` em `/etc/falco/falco_rules.local.yaml`. Desde então, o serviço do Falco no `controlplane` **não funciona mais**.

Há indícios de que algum container do cluster está **adicionando usuários** ao seu próprio `/etc/passwd` periodicamente.

## Tarefa

1. Corrija a regra `Write below etc in container` em `/etc/falco/falco_rules.local.yaml` para que ela:
   - dispare quando um processo **dentro de um container** abrir para **escrita** qualquer arquivo abaixo de `/etc/`;
   - tenha prioridade `WARNING`;
   - tenha como output **exatamente** o formato:
     ```
     %evt.time,%container.id,%container.image.repository,%user.uid,%proc.name
     ```
2. O serviço do Falco deve estar rodando (`active`) com a regra carregada.
3. Colete os alertas desta regra por **pelo menos 30 segundos** e salve-os em `/opt/course/22/q3/falco.log` (uma linha por alerta).
4. A partir do container ID dos alertas, identifique o Pod responsável e grave `<namespace>/<pod>` em `/opt/course/22/q3/pod.txt`.
5. Encontre no host o PID do processo principal desse container e descubra, via `/proc/<pid>/exe`, o caminho do executável que ele está rodando. Grave esse caminho em `/opt/course/22/q3/exe.txt`.
6. Apague o Pod responsável. Nenhum outro Pod deve ser removido.

## Documentação permitida

- https://falco.org/docs/concepts/rules/basic-elements/
- https://falco.org/docs/reference/rules/supported-fields/
- https://falco.org/docs/concepts/outputs/formatting/
- https://kubernetes.io/docs/tasks/debug/debug-cluster/crictl/
- https://man7.org/linux/man-pages/man5/proc.5.html

Quando terminar: `bash verify.sh`
