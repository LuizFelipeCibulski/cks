# D1: Falco, override de regra padrão + saída em arquivo

**Domínio:** Monitoring, Logging and Runtime Security · **Tempo-alvo:** 6 min

## Preparação

```bash
bash setup.sh   # root, no controlplane (instala o Falco se precisar)
```

## Contexto

O Falco roda como serviço systemd no `controlplane`. No namespace `d1` existe o Pod `webshell`.
O SOC quer receber os alertas de shell interativo em containers num formato CSV e num arquivo local.

## Tarefa

1. **Sem editar** `/etc/falco/falco_rules.yaml`, altere a regra padrão `Terminal shell in container` para que:
   - a prioridade seja `CRITICAL`;
   - o output seja **exatamente**:
     ```
     %evt.time,%container.id,%user.name,%proc.name
     ```
2. Configure o Falco para **também** gravar os alertas no arquivo `/var/log/falco/alerts.log` (saída em texto, não JSON).
3. O serviço do Falco deve estar `active` com as mudanças carregadas.
4. Abra um shell interativo no Pod `d1/webshell` (`kubectl exec -it ... -- sh`) e confirme que o alerta aparece no arquivo.

## Documentação permitida

- https://falco.org/docs/concepts/rules/overriding/
- https://falco.org/docs/concepts/outputs/channels/
- https://falco.org/docs/reference/rules/supported-fields/

Quando terminar: `bash verify.sh`
