# D2: Falco, regra customizada + caça ao workload

**Domínio:** Monitoring, Logging and Runtime Security · **Tempo-alvo:** 8 min

## Preparação

```bash
bash setup.sh   # root, no controlplane
```

## Contexto

Containers imutáveis não deveriam rodar gerenciadores de pacote. Há Deployments nos namespaces
`store` e `legacy`, e suspeita-se que alguns estão executando `apk` / `apt-get` em runtime.

## Tarefa

1. Crie em `/etc/falco/falco_rules.local.yaml` a regra `Package management in container` que:
   - dispare quando um **processo for iniciado** dentro de **um container** e o nome do processo for um de:
     `apk`, `apt`, `apt-get`, `dpkg`, `yum`, `dnf`;
   - tenha prioridade `ERROR`;
   - tenha output **exatamente**:
     ```
     %evt.time,%container.id,%container.image.repository,%proc.name
     ```
2. Com o Falco rodando, colete os alertas dessa regra por pelo menos 30 s e salve-os em
   `/opt/course/25/d2/falco.log`.
3. Usando o `container.id` dos alertas, descubra quais **Deployments** são responsáveis. Escale-os para `0`
   e grave-os em `/opt/course/25/d2/report.txt`, um por linha, no formato `<namespace>/<deployment>`.
4. Nenhum outro Deployment pode ser alterado.

## Documentação permitida

- https://falco.org/docs/concepts/rules/basic-elements/
- https://falco.org/docs/reference/rules/supported-fields/
- https://kubernetes.io/docs/tasks/debug/debug-cluster/crictl/

Quando terminar: `bash verify.sh`
