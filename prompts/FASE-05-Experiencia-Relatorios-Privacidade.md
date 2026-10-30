# Fase 05 — Dashboard, relatórios, backup e privacidade

## Objetivo
Completar a experiência principal e garantir exportação, backup/restauração e transparência de privacidade.

## Tarefas
1. Dashboard: saldos por conta/total, receitas e despesas do período, orçamento, compromissos, metas e previsão.
2. Distinguir visualmente saldo real e projetado; gráficos legíveis e acessíveis.
3. Relatórios por período/categoria/conta e exportação CSV; PDF pode ser adiado.
4. Definir backup versionado com versão do esquema, moeda/configurações e tabelas necessárias.
5. Validar integridade/versão/estrutura do backup antes de restaurar; pedir confirmação e apresentar resumo.
6. Preservar a base atual antes de uma restauração destrutiva; erro não pode deixar base parcial.
7. Testar backup → restauração em base limpa → comparar dados; testar ficheiro corrompido e versão não suportada.
8. Documentar localização dos dados, exportação, cópia fora do dispositivo e recuperação.
9. Não adicionar analytics, anúncios, rastreio, upload ou chamadas de rede.
10. Se implementar PIN/biometria, usar APIs seguras; não criar criptografia própria. Explicar que bloquear a interface não cifra SQLite.
11. Pedir apenas permissões móveis necessárias e iniciar exportação por ação do utilizador.

## Testes
CSV com acentos/separadores/datas; backup/restauro preserva IDs, saldos e relações; backup inválido não altera dados; falha de restauro não deixa base parcial; funcionalidades essenciais offline; estados vazios e confirmação.

## Aceitação
Utilizador consegue exportar/restaurar dados; privacidade e limitações de proteção local documentadas.
