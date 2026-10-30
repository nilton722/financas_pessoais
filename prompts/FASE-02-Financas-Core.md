# Fase 02 — Contas, categorias e movimentos

Leia os documentos-base e verifique a Fase 01 antes de alterar.

## Objetivo
Implementar contas, categorias, rendimentos, despesas e transferências.

## Tarefas
1. Criar modelos tipados, repositórios SQLite, serviços de domínio e interfaces CRUD/arquivo.
2. Implementar contas: dinheiro, banco, carteira móvel, poupança e outro; saldo inicial e data.
3. Implementar categorias predefinidas/personalizadas para rendimento e despesa; arquivar categorias referenciadas.
4. Criar formulários de movimento com validação de tipo, valor positivo, data, conta, categoria e descrição.
5. Implementar transferências entre duas contas distintas como operação atómica e um registo lógico.
6. Calcular saldos por conta e consolidado apenas para contas da mesma moeda.
7. Criar lista de movimentos com filtros por data, conta, tipo e categoria.
8. Garantir que correções retroativas atualizam saldos e relatórios.
9. Usar inteiros para dinheiro e consultas parametrizadas; não colocar SQL ou regras nos widgets.
10. Não registar notas ou valores pessoais em logs.

## Testes
Saldo inicial + rendimento − despesa; transferência debita origem e credita destino; transferência não altera saldo consolidado; rejeitar valores zero/negativos; rejeitar conta/categoria inválida; filtros por intervalo; rollback de operação incompleta; edição/eliminação lógica recalcula saldo.

## Aceitação
Fluxos funcionam offline e saldos correspondem aos testes. Executar análise e testes e reportar resultados reais.
