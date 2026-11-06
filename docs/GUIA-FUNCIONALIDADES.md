# Guia de funcionalidades — quando usar e como usar

Este guia responde a duas perguntas para cada funcionalidade da Nô Dinheru:
**quando usar** e **o que muda nos números**. Para instalação, assinatura,
resolução de problemas e detalhes de backup, use o
[Manual](MANUAL.md). Para o formato técnico do backup, veja
[BACKUP.md](BACKUP.md).

A app é local e offline. Os montantes são inteiros de **FCFA (XOF)** e as datas
financeiras aparecem como `DD/MM/AAAA`. A moeda, o idioma e o fuso são
configurações iniciais e aparecem nas Definições apenas para consulta.

## A distinção que explica a app: real vs planeado

| Camada | O que inclui | Altera o saldo real? | Onde aparece |
|---|---|---|---|
| **Real** | Movimentos de rendimento, despesa e transferência | Sim; a transferência só altera os saldos das contas envolvidas | Saldos, Painel, Relatórios, Orçamentos, ponto de partida da Previsão |
| **Planeado** | Compromissos, ocorrências de recorrências, orçamentos, metas e dívidas por pagar | Não | Planeamento, alertas e Previsão (compromissos e ocorrências) |
| **Referência** | Contas e categorias | Não | Todas as funcionalidades que as usam |

Regra prática: **se o dinheiro já saiu ou entrou, é um movimento; se ainda vai
sair ou entrar, é planeamento**. Um compromisso só passa a dinheiro real
quando é pago.

## Escolher a funcionalidade certa

| Quero… | Uso | Porquê |
|---|---|---|
| Registar dinheiro que já entrou ou saiu | **Movimento** (rendimento/despesa) | Altera o saldo real e os relatórios |
| Passar dinheiro entre contas minhas | **Transferência** | Move saldo entre contas sem contar como rendimento ou despesa |
| Registar uma conta futura, uma só vez | **Compromisso** | Fica pendente até ser pago; entra na previsão |
| Registar algo que se repete | **Recorrência** | Gera compromissos periódicos a partir de uma regra |
| Controlar dinheiro que devo ou me devem | **Dívida** | Pendente calculado a partir de pagamentos reais |
| Definir um limite mensal de gastos | **Orçamento** | Compara despesas reais com um limite por categoria |
| Juntar dinheiro para um objetivo | **Meta de poupança** | Mostra o progresso através do saldo de uma conta |
| Saber se o saldo chega até uma data | **Previsão** | Projeta saldo com compromissos e histórico |
| Perceber para onde foi o dinheiro | **Relatórios** | Agrupa o passado por categoria ou conta |
| Guardar ou recuperar os dados | **Backup** | Cria ou repõe uma cópia completa |
| Impedir a abertura por outra pessoa | **Bloqueio** | Pede as credenciais do telefone ao abrir |
| Ser avisado sem abrir a app | **Lembretes** | Agenda notificações locais na véspera e no dia do vencimento |

## Painel

**Quando usar.** É o ponto de partida do dia a dia: mostrar quanto existe,
quanto entrou e saiu no mês, como está o planeamento e qual é a projeção a 30
dias. Não serve para editar dados; para isso, use os separadores.

**O que mostra.**

- **Saldo real consolidado** — soma os saldos das contas ativas na moeda de
  referência, com movimentos até hoje. Exclui contas arquivadas e contas noutra
  moeda.
- **Rendimentos do mês** e **Despesas do mês** — apenas movimentos do mês civil
  atual; transferências ficam de fora.
- **Previsão (30 dias)** — saldo projetado e menor saldo no horizonte de 30
  dias. Tocar abre a previsão completa. Não altera o saldo real.
- **Planeamento** — orçamentos do mês, compromissos pendentes e metas ativas.
- **Contas** — as primeiras cinco contas ativas; “Ver todas” abre a lista
  completa.
- **Atalhos** no topo — Relatórios e Definições.

**Bom saber.** Os alertas de vencimento, dívidas e orçamentos excedidos
aparecem no separador **Plano**, não no Painel. O rodapé indica que os dados são
locais e mostra o fuso e a versão do esquema.

## Contas

**Quando usar.** Crie uma conta para cada sítio real onde guarda dinheiro:
carteira, conta bancária, carteira móvel, poupança ou outro. Uma conta por
sítio torna os saldos e os relatórios úteis; uma conta única para tudo esconde
para onde o dinheiro foi.

**Como usar.**

1. **Contas → Nova conta**.
2. Preencha **Nome**, **Tipo**, **Saldo inicial** e **Data de abertura**.
3. Guarde. A moeda é fixa em **FCFA (XOF)** nesta versão.

Para alterar, toque na conta. Para a esconder dos saldos, use o ícone de olho e
confirme **Arquivar conta**. O ícone volta a mostrar as arquivadas, onde pode
desarquivar.

**O que muda nos números.**

- O saldo da conta é o saldo inicial mais rendimentos, menos despesas e mais ou
  menos transferências, até hoje.
- Arquivar retira a conta do saldo consolidado, mas mantém os movimentos e o
  histórico; é reversível.
- Não é possível eliminar contas.

**Cuidados.** A data de abertura não pode ser futura e o saldo inicial tem de
ser um inteiro não negativo. Evite guardar números completos de cartões ou
contas bancárias nas notas. Para uma meta, crie uma conta de poupança separada:
o progresso da meta lê o saldo dessa conta.

## Categorias

**Quando usar.** Para classificar rendimentos e despesas. As predefinidas
cobrem o essencial; crie uma categoria personalizada quando um tipo de gasto se
repete e quer vê-lo separado nos relatórios, orçamentos e previsão.

**Como usar.**

1. **Categorias → Nova categoria**.
2. Escolha **Nome** e **Tipo** (Rendimento ou Despesa).
3. Guarde. Para editar, toque na categoria.

O tipo não pode ser alterado depois de criada. Uma categoria personalizada com
o mesmo nome e tipo de outra ativa é recusada. Para a retirar das novas
utilizações, use **Arquivar** e confirme; o histórico mantém-se e a categoria
deixa de aparecer nos formulários.

**O que muda nos números.** A categoria determina o agrupamento dos relatórios,
o gasto de um orçamento e a estimativa histórica da previsão. Arquivar não
altera movimentos antigos nem apaga nada. Não é possível eliminar categorias.

## Movimentos

**Quando usar.** Sempre que o dinheiro **já entrou ou saiu**, hoje ou no
passado: salário, compra, conta paga, rendimento recebido. Não use movimentos
para datas futuras — a data não pode ser posterior a hoje; para o futuro, use
um compromisso ou uma recorrência.

**Como usar.**

1. **Movimentos → Novo movimento**.
2. Escolha **Rendimento** ou **Despesa**.
3. Preencha **Montante**, **Data**, **Conta** e **Categoria**; descrição e notas
   são opcionais.
4. Guarde.

Na lista, o ícone de filtros abre ou fecha os campos de tipo, conta, categoria
e período, e mostra um ponto quando há filtros ativos. O ícone de pesquisa
abre um campo que procura em descrição, notas, categoria e nomes das contas.
Toque num movimento para editar; no menu, **Mover para a lixeira** tira-o dos
saldos e relatórios sem o apagar. O ícone de lixeira no topo abre os
movimentos eliminados, onde pode **Restaurar** ou **Eliminar
definitivamente**. Restaurar devolve o movimento aos saldos; se ele pagava um
compromisso ou dívida, a ligação é reposta, desde que outro movimento não
tenha entretanto ocupado esse valor.

**O que muda nos números.**

- O saldo da conta e o consolidado mudam imediatamente.
- Entra nos rendimentos/despesas do mês, nos relatórios e no gasto do orçamento
  da categoria.
- Serve de ponto de partida e de histórico para a previsão.
- Uma transferência tem efeito diferente; ver a secção seguinte.

**Cuidados.**

- O tipo não pode ser alterado depois de guardado; elimine e recrie se for
  mesmo necessário.
- Se o movimento estiver ligado ao pagamento de um compromisso ou de uma
  dívida, movê-lo para a lixeira reabre esse pagamento e recalcula o pendente;
  restaurá-lo volta a fechá-lo. É assim que se corrige um pagamento feito por
  engano. Ao editá-lo, o novo montante não pode exceder o valor do compromisso
  ou da dívida.
- Não registe um movimento manual para um pagamento que já fez pelo botão
  **Pagar** de um compromisso ou dívida: isso duplicaria o dinheiro.

## Transferências

**Quando usar.** Quando o dinheiro muda de uma conta sua para outra conta sua:
levantar dinheiro, passar da conta bancária para a carteira móvel, pôr dinheiro
de lado na poupança. Não é rendimento nem despesa.

**Como usar.**

1. **Movimentos → Novo movimento → Transferência**.
2. Indique **Montante**, **Data**, **Conta de origem** e **Conta de destino**.
3. Guarde. As contas têm de ser diferentes e usar a mesma moeda.

**O que muda nos números.**

- A conta de origem perde o montante; a de destino ganha o mesmo montante.
- O saldo consolidado **não** muda, porque o dinheiro continua a ser seu.
- Fica fora dos rendimentos, despesas, resultado dos relatórios e gasto dos
  orçamentos. Na previsão é neutra.

**Cuidado.** Não registe uma transferência como duas operações separadas
(despesa numa conta e rendimento na outra): isso inflaciona as despesas e os
rendimentos e distorce os relatórios.

## Compromissos

**Quando usar.** Para uma conta futura, única, com vencimento: renda, fatura,
mensalidade, salário que ainda vai receber. Se o mesmo valor se repete, use uma
recorrência. Se já pagou ou recebeu, use um movimento.

**Como usar.**

1. **Plano → Compromissos → Novo compromisso**.
2. Escolha **Rendimento** ou **Despesa**, indique **Valor**, **Vencimento** e
   **Descrição**. Conta e categoria são opcionais na criação.
3. Para liquidar, abra o menu do compromisso e escolha **Pagar**. Confirme o
   **Valor a pagar** (pré-preenchido com o que falta), a **Data**, a **Conta** e
   a **Categoria**; a conta e a categoria passam a ser obrigatórias no
   pagamento e a data não pode ser futura.
4. Para desistir, escolha **Cancelar compromisso** e confirme.

**O que muda nos números.**

- Enquanto não é pago, o compromisso **não altera o saldo real**; entra na
  previsão na data de vencimento.
- Pagar cria exatamente um movimento real de despesa ou rendimento e reduz o
  valor em falta. Pagamentos parciais são permitidos; o total nunca pode
  exceder o que falta.
- Cancelar retira o compromisso da previsão, mas mantém os movimentos dos
  pagamentos já feitos.
- Um compromisso totalmente pago ou cancelado fica bloqueado para edição; para
  reverter, elimine o movimento do pagamento. Um novo valor não pode ficar
  abaixo do já pago.

**Cuidado.** Não crie também um movimento manual para o mesmo pagamento. O
botão **Pagar** já regista o dinheiro; duplicar conta o valor duas vezes.

## Recorrências

**Quando usar.** Para um rendimento ou despesa planeada que se repete todas as
semanas, meses ou anos: salário, renda, assinatura, mensalidade. Para algo
único, use um compromisso.

**Como usar.**

1. **Plano → Recorrências → Nova recorrência**.
2. Indique o tipo, o **Valor por ocorrência**, a **Frequência** (Semanal,
   Mensal ou Anual), o **Início** e, se quiser, uma **Data de fim**. Conta e
   categoria são opcionais.
3. Guarde. As próximas ocorrências são criadas como compromissos planeados até
   90 dias à frente quando abre o Planeamento, guarda a regra, usa o botão de
   sincronizar ou calcula a previsão.
4. Use o interruptor para **pausar** ou **reativar**. Pausar impede novas
   ocorrências; as que já existem mantêm-se.

**O que muda nos números.** As ocorrências são compromissos, não dinheiro
real: só alteram o saldo quando cada uma é paga. Uma recorrência mensal ou
anual ajusta o dia ao último dia do mês quando esse dia não existe (por
exemplo, dia 31 num mês de 30 dias).

**Cuidados.** Uma recorrência não paga sozinha. Pode editar o tipo, a
frequência, o início e o fim mesmo depois de existirem ocorrências: a app
pede confirmação e reconstrói apenas as ocorrências **futuras ainda sem
pagamentos**. As ocorrências passadas e as que já receberam algum pagamento
mantêm-se intactas. Se existirem ocorrências futuras pagas, a alteração é
recusada até as reverter. Alterar só o valor ou a descrição atualiza as
ocorrências pendentes e as próximas gerações. Não é possível eliminar a
regra; só pausar.

## Orçamentos

**Quando usar.** Para definir um limite mensal de despesa por categoria e
compará-lo com o que realmente gastou: alimentação, transporte, lazer. Não é
uma ordem de pagamento nem bloqueia gastos; é uma referência.

**Como usar.**

1. **Plano → Orçamentos**. Navegue entre meses com as setas ou volte com
   **Mês atual**.
2. **Novo orçamento**: escolha uma categoria de **despesa**, o mês e o
   **Limite mensal**.
3. Para ajustar, use **Alterar limite** no menu do orçamento; para retirar,
   **Remover** e confirme.

**O que muda nos números.**

- O gasto é a soma das despesas reais da categoria no mês; rendimentos,
  transferências e outras categorias ficam de fora.
- O restante é o limite menos o gasto; a percentagem pode passar de 100% e o
  estado **Excedido** aparece quando o gasto é maior do que o limite.
- O limite é definido por mês e não transita automaticamente para o mês
  seguinte; crie ou ajuste o orçamento do mês quando precisar.
- Um orçamento excedido gera alerta no **Plano**.

**Cuidados.** O orçamento não impede registar despesas acima do limite; serve
para as ver e corrigir. Categorias de rendimento são recusadas. Se remover o
orçamento, as despesas e os movimentos continuam intactos.

## Metas de poupança

**Quando usar.** Para juntar dinheiro com um objetivo e prazo, como fundo de
emergência, uma compra ou uma viagem. A meta não é uma despesa; é uma forma de
acompanhar o progresso.

**Como usar.**

1. **Plano → Metas de poupança → Nova meta**.
2. Indique **Nome**, **Alvo**, data-alvo opcional, uma **Conta associada**
   opcional e notas.
3. Guarde. Para esconder, arquive com confirmação.

**O que muda nos números.**

- O progresso é o **saldo real da conta associada** até hoje, limitado a 100%.
  Sem conta associada, o progresso é 0.
- A meta não altera saldos, orçamentos nem relatórios por si só.
- Quando o valor atual atinge o alvo, a meta aparece como concluída.

**Cuidados.** Como o progresso lê todo o saldo da conta, usar a conta do dia a
dia inflaciona o progresso. O melhor é associar uma conta de poupança dedicada
e alimentá-la com **transferências**, não com despesas. Não é possível eliminar
metas; pode arquivá-las.

## Dívidas

**Quando usar.** Quando deve dinheiro a alguém ou alguém lhe deve dinheiro, e
quer acompanhar pagamentos parciais: empréstimos, compras a prestações, dinheiro
emprestado a um familiar. Para uma conta futura simples e única, um compromisso
chega.

**Como usar.**

1. **Plano → Dívidas → Nova dívida**.
2. Escolha **A pagar** ou **A receber**, indique **Descrição**, **Contraparte**,
   **Valor original** e, se quiser, **Vencimento**.
3. No menu da dívida, escolha **Registar pagamento**: indique montante, data,
   conta e categoria. Pagamentos parciais são permitidos, mas nunca acima do
   que falta; a data do pagamento não pode ser futura.
4. Para desistir de uma dívida ainda não liquidada, use **Cancelar dívida**.

**O que muda nos números.**

- Criar a dívida não altera o saldo: é apenas uma obrigação registada.
- Cada pagamento cria um movimento real — despesa numa dívida a pagar,
  rendimento numa dívida a receber — e reduz o pendente.
- A dívida fica liquidada quando os pagamentos atingem o valor original.
- Uma dívida cancelada mantém os pagamentos já registados. Dívidas liquidadas
  ou canceladas não podem ser editadas nem canceladas; para reverter, elimine
  os movimentos.
- As dívidas em aberto **não entram na previsão** enquanto não forem pagas. Se
  precisa de antecipar um pagamento no horizonte, registe-o como compromisso;
  quando pagar a dívida, cancele esse compromisso para não contar o valor duas
  vezes.

**Cuidado.** Não registe a dívida como despesa no momento em que a cria. Só o
pagamento move dinheiro; registar os dois duplica o impacto no saldo.

## Previsão

**Quando usar.** Para responder a “o saldo aguenta até ao fim do mês?” ou “e
nos próximos três meses?”. É uma estimativa explicável para planeamento, não
uma garantia nem um orçamento.

**Como usar.** No Painel, toque no cartão **Previsão (30 dias)**. Escolha
**7, 30 ou 90 dias**. Leia o saldo projetado, o menor saldo e a respetiva data,
o gráfico diário, os compromissos considerados e os pressupostos, a qualidade
dos dados e as limitações.

**O que entra no cálculo.**

- O saldo real consolidado de hoje como ponto de partida.
- Compromissos pendentes (líquidos do já pago), na data de vencimento; os
  vencidos contam na data de corte.
- Ocorrências de recorrências até 90 dias.
- Despesas históricas por categoria, mas só com histórico suficiente: três
  meses civis completos com despesas e pelo menos seis despesas no total; cada
  categoria precisa de estar em pelo menos dois meses e ter mediana positiva.
- Categorias com compromissos no horizonte ficam de fora da estimativa
  histórica para não contar duas vezes.

**O que não entra.** Rendimentos não planeados, dívidas ainda não pagas, metas
de poupança e limites de orçamento. Transferências são neutras. Sem histórico
suficiente, a previsão mostra apenas os compromissos conhecidos e assinala a
limitação.

**Cuidados.** A previsão não antecipa despesas que não registou nem rendimentos
futuros sem compromisso. Se o saldo projetado ficar negativo, o cartão avisa;
use isso para ajustar compromissos, não como certeza.

## Relatórios

**Quando usar.** Para rever um período passado e perceber o resultado:
rendimentos, despesas e saldo do período, por categoria ou por conta. Também
serve para exportar os movimentos em CSV.

**Como usar.**

1. Toque no ícone **Relatórios** no topo do Painel.
2. Escolha o período: **Este mês**, **Mês anterior**, **Últimos 3 meses** ou
   **Personalizado**.
3. Alterne o agrupamento entre **Categoria** e **Conta**.
4. Se houver movimentos no período, use **Exportar CSV** (cópia na pasta da
   app) ou **Guardar CSV em…** (escolher Downloads, Drive ou outro destino).

**O que mostra.**

- Rendimentos, despesas e resultado (rendimentos menos despesas) do período.
- As transferências aparecem à parte e não entram no resultado.
- O CSV é UTF-8 com BOM, separador `;`, datas `DD/MM/AAAA` e colunas de data,
  tipo, descrição, categoria, conta, conta de destino, montante e notas.
  **Exportar CSV** grava na pasta de exportações; **Guardar CSV em…** grava
  também no destino escolhido no seletor do sistema. A app mostra o caminho e
  permite copiá-lo.

**Cuidados.** Os relatórios são de leitura: não alteram dados. Sem movimentos
no período, a exportação fica indisponível. A app não envia o CSV: se escolher
um serviço de nuvem, é esse serviço que transfere o ficheiro. Não existe exportação em PDF nesta
versão. A exportação CSV não substitui o backup: o backup é o único ficheiro
que permite repor a app completa.

## Backup, importar e restaurar

Estas ações parecem iguais, mas servem para coisas diferentes.

| Ação | Quando usar | O que faz |
|---|---|---|
| **Criar backup agora** | Rotina, antes de atualizar, antes de mudar de telefone | Cria um JSON cifrado ou simples com todas as tabelas e configurações na pasta da app |
| **Guardar backup em…** | Quer a cópia fora do telefone (Drive, Downloads, cartão SD) | Cria um backup (cifrado ou simples) e abre o seletor de gravação do sistema |
| **Restaurar** | Voltar atrás ou repor num telefone onde o ficheiro já está na lista | Valida, cria uma cópia `pre-restore` e substitui toda a base |
| **Importar de um ficheiro** | O backup está fora da app (Drive, Downloads, cartão SD, outro telefone) | Abre o seletor do sistema, valida e restaura o ficheiro escolhido |

**Como criar.** **Definições → Backup e restauração → Criar backup agora.**
Escolha **Cifrado** (recomendado) ou **Sem cifra**. No modo cifrado, defina uma
frase-passe com pelo menos 8 caracteres e repita-a. A frase não é guardada e,
se for esquecida, o backup não pode ser aberto. A lista mostra data, número de
registos, tamanho e integridade; os cifrados aparecem com um cadeado.

**Como guardar fora.** **Guardar backup em…** cria um backup novo e abre logo o
seletor do sistema com o nome preenchido. Escolha Downloads, Google Drive,
OneDrive, um cartão SD ou outro destino. A app não acede à rede: se escolher
uma nuvem, é a aplicação desse fornecedor que transfere o ficheiro, com a sua
conta. Cancelar o seletor mantém apenas a cópia local.

**Como restaurar.** Toque no backup da lista. Se estiver cifrado, escreva a
frase-passe; uma frase errada mostra um aviso e permite tentar outra vez. Depois
confirme a pré-visualização e **Restaurar**, depois **Substituir dados**. Antes
de substituir, a app cria automaticamente uma cópia da base atual
(`pre-restore-…json`). O restauro corre numa única transação; se falhar, a base
atual fica intacta.

**Como importar.** **Importar de um ficheiro** e escolha o ficheiro no seletor
do sistema. Não são pedidas permissões de armazenamento. Se o backup estiver
cifrado, é pedida a frase-passe. O ficheiro é validado e restaurado com as
mesmas regras do restauro local.

**Como recuperar num telefone novo.** Instale a app, abra-a uma vez e use
**Importar de um ficheiro** para escolher o backup que guardou no Drive ou em
Downloads. Não precisa de copiar o ficheiro para a pasta da app.

**O que muda.** O restauro **substitui** todos os dados; não funde backups.
Configurações como o bloqueio ao abrir também são repostas. Um backup cifrado
protege o conteúdo com AES-256-GCM e uma chave derivada da frase-passe; um
backup simples fica legível e o checksum só deteta corrupção acidental. A cópia
automática `pre-restore-…json` é sempre simples, porque fica na pasta privada da
app ao lado da base. Proteja a conta, a frase-passe e as cópias. Em Android 11
ou mais recente, a pasta da app fica oculta; use **Guardar backup em…** (ou
`adb pull` para ficheiros já escritos nessa pasta).

**Cuidados.** Um backup só no telefone perde-se ao desinstalar ou perder o
aparelho. Faça cópias periódicas para fora. Se restaurar por engano, a cópia
`pre-restore` criada nesse momento permite voltar atrás.

## Bloqueio ao abrir

**Quando usar.** Se o telefone é partilhado ou emprestado e quer uma barreira
antes de mostrar os dados. A opção só fica disponível quando o telefone tem
PIN, padrão, palavra-passe ou biometria configurados no sistema.

**Como usar.** **Definições → Bloqueio → Pedir bloqueio do telefone ao abrir.**
Ligar o interruptor durante a sessão só se aplica na abertura seguinte. Ao
abrir a app, o sistema pede o desbloqueio. Cancelar mantém o ecrã de bloqueio;
**Desbloquear** tenta novamente. Depois de 60 segundos em segundo plano, o
pedido volta; regressos curtos, como escolher um ficheiro, mantêm a sessão. Se
remover as credenciais do telefone, a app explica a situação e oferece **Abrir
sem bloqueio**.

**O que muda.** Nada nos dados: o bloqueio é uma barreira de interface. A base
SQLite e as exportações continuam sem cifra; os backups só ficam cifrados se
escolher essa opção ao criá-los. Restaurar um backup criado com o bloqueio
ligado volta a ativá-lo neste telefone, com as credenciais locais.

**Cuidados.** O bloqueio não substitui o bloqueio do telefone nem cifra a base;
não protege contra root ou acesso direto à base. Mantenha o dispositivo
protegido, os backups cifrados e a frase-passe em local seguro.

## Lembretes no telemóvel

**Quando usar.** Se quer ser avisado de um vencimento sem ter a app aberta, ou
receber um resumo quando um orçamento do mês foi excedido. É útil para contas
fixas e para não deixar passar a data de pagamento.

**Como usar.** **Definições → Lembretes**, ligue **Lembretes no telemóvel** e
confirme a permissão de notificações. Toque em **Hora do lembrete** para
escolher a hora (predefinição 09:00). A app agenda a véspera e o dia do
vencimento de cada compromisso em aberto nos próximos 365 dias, com descrição,
valor em falta e conta. Compromissos pagos, cancelados ou vencidos não geram
avisos.

**O que muda.** No último dia do mês é agendado um único resumo se houver
orçamentos excedidos; tocar no aviso abre os orçamentos. Alterar compromissos,
orçamentos ou a hora recria os mesmos avisos sem duplicar. Desligar o
interruptor cancela os avisos pendentes.

**Cuidados.** Sem rede: tudo é agendado no telefone. O sistema pode atrasar a
entrega em poupança de energia e mostra o conteúdo no ecrã de bloqueio conforme
as pré-visualizações configuradas. Se desativar as notificações da app no
sistema, as definições mostram um aviso e nada é agendado até a permissão
voltar. Um backup restaurado com lembretes ligados mantém a preferência, mas
cada telefone tem de autorizar as notificações.

## Definições e privacidade

- **Privacidade** explica que os dados ficam no dispositivo, sem internet,
  analytics ou telemetria.
- **Moeda, idioma e fuso** são apenas de consulta nesta versão.
- **Lembretes** ficam desligados até serem ativados; a permissão de
  notificações é pedida apenas nesse momento.
- **Caminhos** mostram onde ficam a base, os backups e as exportações.
- **Sobre** mostra a versão e a identificação da app.
- A versão de release não pede `INTERNET` nem permissões de armazenamento.

## Rotinas recomendadas

| Quando | O que fazer |
|---|---|
| Todos os dias | Registar os movimentos do dia; corrigir datas e montantes enquanto se lembra |
| Todas as semanas | Abrir **Plano**, ver os alertas (vencidos, próximos 7 dias, orçamentos excedidos) e pagar os compromissos vencidos |
| Todos os meses | Criar ou ajustar os orçamentos do mês; rever **Relatórios**; confirmar que os saldos das contas batem com a realidade; criar um backup |
| Antes de atualizar a app | Criar backup e copiá-lo para fora do telefone |
| Antes de mudar de telefone | Backup, copiar o ficheiro, instalar a app nova e usar **Importar de um ficheiro** |
| Se o telefone é partilhado | Ativar o bloqueio do telefone e o bloqueio ao abrir |

## Erros comuns e alternativa

| Erro | Consequência | Em vez disso |
|---|---|---|
| Registar uma transferência como despesa + rendimento | Rendimentos e despesas inflacionados; consolidado errado | Usar **Transferência** |
| Registar uma despesa futura como movimento | A app recusa a data futura | Usar **Compromisso** ou **Recorrência** |
| Pagar um compromisso e criar também o movimento à mão | Dinheiro contado duas vezes | Usar só **Pagar** no compromisso |
| Registar a criação de uma dívida como despesa | Saldo reduzido antes de pagar | Criar a dívida; só o pagamento cria movimento |
| Registar uma poupança como despesa | A poupança desaparece dos relatórios e o saldo consolidado cai | Usar **Transferência** para a conta de poupança |
| Contar com o orçamento para limitar gastos | O orçamento não bloqueia despesas | Usar o alerta de excedido e corrigir os movimentos |
| Pensar que a recorrência paga sozinha | Nenhum dinheiro se move até pagar a ocorrência | Pagar cada compromisso gerado |
| Assumir que o orçamento passa para o mês seguinte | O limite é por mês | Criar ou ajustar o orçamento do novo mês |
| Restaurar um backup para juntar dados | O restauro substitui tudo | Fazer backup antes; não há fusão |
| Arquivar uma conta/categoria para “apagar” | O histórico mantém-se e a conta/categoria só fica oculta | Arquivar para esconder; eliminar movimentos individualmente se for o caso |
| Eliminar o movimento de um pagamento sem perceber | O compromisso/dívida reabre e o pendente aumenta | Usar a eliminação apenas para corrigir um pagamento errado |

## Glossário rápido

- **Saldo real** — dinheiro efetivamente registado numa conta até hoje.
- **Saldo consolidado** — soma das contas ativas na moeda de referência.
- **Saldo projetado** — estimativa da previsão; não é dinheiro real.
- **Pendente** — parte de um compromisso ou dívida que ainda falta pagar.
- **Ocorrência** — compromisso gerado por uma recorrência numa data.
- **Arquivar** — esconder sem apagar; o histórico mantém-se.
- **Eliminação lógica** — o movimento sai dos cálculos, mas fica na base.
