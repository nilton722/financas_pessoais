# Fase 04 — Motor de previsão local explicável

Ler as regras de previsão em `docs/SPEC.md`.

## Objetivo
Implementar motor determinístico em Dart, sem Python, backend ou chamadas de rede.

## Regras
- Definir data de corte e saldo real de abertura.
- Projetar por dia em horizontes de 7, 30 e 90 dias.
- Incluir compromissos conhecidos e ocorrências recorrentes futuras exatamente uma vez.
- Excluir compromissos cancelados e não contar novamente os já pagos.
- Transferências próprias não alteram saldo consolidado.
- Separar realizados, compromissos confirmados e estimativas históricas.
- Usar histórico apenas quando houver quantidade/qualidade suficiente; caso contrário, mostrar só compromissos conhecidos e explicar a limitação.

## Tarefas
1. Criar tipos `ForecastRequest`, `ForecastResult`, `ForecastDay`, pressupostos e qualidade dos dados.
2. Implementar cenário determinístico de saldo + compromissos.
3. Quando houver histórico suficiente, usar média/mediana histórica por categoria e janela temporal, documentando o método e tornando o critério de suficiência configurável/testável.
4. Mostrar saldo projetado, menor saldo, próximos compromissos e possível saldo negativo.
5. Mostrar data do cálculo, horizonte, pressupostos e limitações; não chamar regras simples de IA.
6. Cenários base/prudente/otimista só se os pressupostos forem explícitos.
7. Guardar snapshots imutáveis apenas se necessários para comparar previsões; incluir data de corte, versão do algoritmo e parâmetros.

## Testes
Sem histórico; só compromissos; histórico suficiente/insuficiente; compromisso pago/cancelado; transferências; pagamento sem dupla contagem; correção retroativa; fim de mês/ano; mesmos dados produzem mesmo resultado.

## Aceitação
Motor executa localmente, é reproduzível e explicável. Não adicionar ML sem justificação e avaliação documentadas.
