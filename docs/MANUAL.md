# Manual de instalação e uso

Aplicação Android offline de finanças pessoais. Não tem backend, login remoto,
anúncios, analytics nem telemetria.

Para escolher entre funcionalidades parecidas (movimento, transferência,
compromisso, recorrência, dívida, orçamento ou meta) e perceber o efeito de
cada uma nos saldos, nos relatórios e na previsão, consulte o
[Guia de funcionalidades](GUIA-FUNCIONALIDADES.md).

## Instalação

### Desenvolvimento

Requisitos: Flutter 3.47.5 (stable), Dart 3.13.3, JDK 17 ou superior.

```bash
flutter pub get
dart run build_runner build
flutter run
```

### APK de release

```bash
flutter test
flutter build apk --release
```

O ficheiro fica em `build/app/outputs/flutter-apk/app-release.apk` e instala-se
com `adb install -r app-release.apk` ou por transferência para o telefone
(permitir instalação de origens desconhecidas apenas para este ficheiro).

Sem `android/key.properties`, o build usa a chave de **debug**: serve para
validação local, não para distribuição. Para assinar a sério, ver
[Assinatura de release](#assinatura-de-release).

## Primeiros passos

1. Abra a app. O painel arranca sem contas e mostra saldo real, previsão e
   resumo de planeamento.
2. Em **Contas**, crie a primeira conta (dinheiro, banco, carteira móvel,
   poupança ou outro) com saldo inicial e data de abertura.
3. Em **Categorias**, use as predefinidas ou crie as suas. Arquivar uma
   categoria mantém o histórico e impede novas utilizações.
4. Registe rendimentos e despesas em **Movimentos**.

As categorias e as configurações iniciais (`XOF`, `pt_PT`, `Africa/Bissau`) são
semeadas uma única vez. Montantes são sempre inteiros de FCFA/XOF.

## Uso diário

- **Movimentos** — rendimento, despesa ou transferência, com conta, categoria,
  data, montante, descrição e notas. O ícone de filtros abre período, conta,
  tipo e categoria; o de pesquisa procura em descrição, notas, categoria e
  contas. Editar pelo toque; **Mover para a lixeira** remove dos saldos e
  relatórios. A lixeira permite restaurar ou eliminar definitivamente.
- **Transferências** — escolha conta de origem e destino. Movem dinheiro entre
  contas próprias: não são rendimento nem despesa e não alteram o saldo
  consolidado. Só são permitidas entre contas com a mesma moeda.
- **Planeamento** — cinco áreas:
  - *Compromissos*: rendimento/despesa futura com vencimento. Pagar total ou
    parcialmente cria exatamente um movimento real; cancelar mantém os
    pagamentos já feitos.
  - *Orçamentos*: limite mensal por categoria de despesa, comparado com gastos
    reais (transferências excluídas).
  - *Recorrências*: regras semanais, mensais ou anuais; geram ocorrências
    planeadas uma única vez, podem ser pausadas e ter tipo, frequência,
    início ou fim editados. A reconstrução aplica-se só às ocorrências
    futuras sem pagamentos; as passadas e pagas mantêm-se.
  - *Metas de poupança*: alvo e progresso lido do saldo real da conta
    associada; uma meta não é uma despesa.
  - *Dívidas*: a pagar ou a receber; o pendente deriva dos pagamentos reais.
- **Previsão** — abra pelo cartão do painel. Horizonte de 7, 30 ou 90 dias,
  com saldo projetado, menor saldo, compromissos conhecidos, pressupostos,
  qualidade dos dados e limitações. É uma estimativa, não uma garantia.
- **Relatórios** — por período, categoria ou conta, com rendimentos, despesas,
  resultado e transferências à parte. A exportação CSV é sempre iniciada pelo
  utilizador; **Guardar CSV em…** abre o seletor do sistema para levar o
  ficheiro para Downloads, Drive ou outro destino.
- **Definições** — privacidade, bloqueio ao abrir, lembretes locais, caminhos
  de dados/backups/exportações, versão e acesso aos backups.

## Backup e restauração

- **Criar backup**: Definições → Backup e restauração → *Criar backup agora*.
  Escolha **Cifrado** (recomendado) ou **Sem cifra**. No modo cifrado, defina
  uma frase-passe com pelo menos 8 caracteres e repita-a; não é guardada. Se a
  esquecer, o ficheiro não pode ser recuperado. É gerado um JSON versionado com
  as 12 tabelas de dados, configurações, contagens e checksum (este último
  dentro do envelope, quando cifrado).
- **Guardar backup em…**: cria um backup novo, com a mesma escolha de cifra, e
  abre o seletor de gravação do sistema para escolher Downloads, Google Drive,
  OneDrive, cartão SD ou outro destino. A app escreve apenas no ficheiro
  escolhido e não acede à rede; a transferência para a nuvem, quando escolhida,
  é feita pelo serviço do fornecedor. A cópia local também fica em `backups`.
- **Restaurar**: toque no ficheiro, confirme a pré-visualização e a advertência.
  Se o backup estiver cifrado, a app pede a frase-passe e valida-a antes de
  mostrar os detalhes; uma frase errada mostra um aviso e permite tentar outra
  vez. Antes de substituir, a app cria um backup de segurança
  `pre-restore-…json` da base atual. O restauro corre numa única transação; se
  algo falhar, a base atual fica intacta.
- **Importar de um ficheiro**: use esta opção para recuperar um backup guardado
  fora da aplicação (por exemplo, no Google Drive, em Downloads ou recebido de
  outro telefone). O seletor de documentos do sistema dá acesso apenas ao
  ficheiro escolhido; não são pedidas permissões de armazenamento. Se estiver
  cifrado, é pedida a frase-passe. A validação, a confirmação e a cópia
  `pre-restore-…json` são as mesmas do restauro local.
- **Onde ficam os ficheiros**: no Android, em
  `Android/data/ao.gb.financas_pessoais/files/backups` (e `exports` para CSV).
  No desktop, na pasta de documentos da aplicação. Os caminhos exatos aparecem
  em Definições. A partir do Android 11, a pasta `Android/data` fica oculta nos
  gestores de ficheiros e na transferência USB; para retirar cópias use
  *Guardar backup em…* ou `adb pull` com depuração USB ativa.
- Copie periodicamente o backup para fora do telefone. Um backup cifrado não é
  legível sem a frase-passe; um backup simples é legível e o checksum só deteta
  corrupção acidental, não adulteração. Guarde a frase-passe num sítio seguro e
  proteja o acesso ao telefone e às cópias.

Detalhe do formato, validação e recuperação: [BACKUP.md](BACKUP.md).

## Bloqueio ao abrir

Em **Definições → Bloqueio**, ative **Pedir bloqueio do telefone ao abrir**. A
opção só fica disponível quando o telefone tem PIN, padrão, palavra-passe ou
biometria configurados no sistema.

- Ao abrir a aplicação, o sistema pede o desbloqueio do telefone. Cancelar
  mantém o ecrã de bloqueio, onde pode tentar novamente.
- Depois de 60 segundos em segundo plano, o pedido volta a aparecer. Regressos
  rápidos, como escolher um ficheiro para importar, mantêm a sessão aberta.
- O bloqueio é uma barreira de interface: a base e as exportações continuam
  sem cifra. Os backups só ficam cifrados se escolher essa opção ao criá-los.
  Não é um PIN próprio da aplicação.
- Se remover o PIN do telefone, a aplicação explica a situação e abre com
  aviso; o interruptor fica desativado até haver credenciais.
- Restaurar um backup criado com a opção ligada ativa o pedido neste telefone,
  usando as credenciais locais.

## Lembretes

Em **Definições → Lembretes**, ative **Lembretes no telemóvel** e escolha a
hora (09:00 por omissão). É pedida a permissão de notificações do sistema;
recusá-la mantém os lembretes desligados.

- Na véspera e no dia do vencimento de cada compromisso em aberto, a aplicação
  mostra um aviso com a descrição, o valor ainda em falta e a conta. O aviso de
  rendimento usa “Receber”; o de despesa usa “Pagar”.
- Compromissos pagos, cancelados ou já vencidos não geram avisos. O horizonte
  é de 365 dias.
- No último dia do mês existe um único aviso quando pelo menos um orçamento do
  mês foi excedido; tocar nele abre os orçamentos.
- Tudo é agendado no próprio telemóvel, sem internet. Ao desligar os lembretes,
  os avisos ainda pendentes são cancelados; os já mostrados podem ser
  dispensados na gaveta de notificações.
- As notificações são recalculadas quando a aplicação abre e quando os
  compromissos ou orçamentos mudam. Os identificadores são estáveis: alterar a
  hora substitui os mesmos avisos em vez de os duplicar.
- Depois de reiniciar o telemóvel, o Android volta a agendar os avisos. Se
  desativar as notificações da aplicação nas definições do sistema, as
  definições da app mostram um aviso e nada é agendado até a permissão voltar.
- A entrega é gerida pelo sistema e pode atrasar alguns minutos com o telefone
  em poupança de energia. O conteúdo pode aparecer no ecrã de bloqueio; ajuste
  as pré-visualizações do sistema se preferir esconder valores.

## Privacidade

- Tudo é local: base SQLite privada da app, backups e exportações no
  armazenamento da app.
- A versão de release **não pede a permissão `INTERNET`**; `INTERNET` existe
  apenas nos manifestos de debug/profile para ferramentas de desenvolvimento.
- Não há analytics, publicidade, telemetria nem envio de dados financeiros.
- O bloqueio opcional usa as credenciais do sistema; a app não recebe nem
  guarda PIN ou biometria. A base continua sem cifra em repouso; os backups só
  ficam cifrados se escolher essa opção ao criá-los. Quem desbloquear o
  telefone e a aplicação consegue ler a base. Proteja o dispositivo e guarde as
  cópias e a frase-passe em local seguro.
- Os lembretes são notificações locais: a app não tem rede nem servidor. O
  sistema pode mostrar descrição, montante e conta no ecrã de bloqueio, conforme
  as pré-visualizações configuradas no telemóvel.
- Logs não incluem dados financeiros pessoais.

Detalhe: [PRIVACY.md](PRIVACY.md).

## Limitações conhecidas

- Uso individual, uma moeda de referência (XOF). Contas noutra moeda não entram
  no saldo consolidado nem nas transferências.
- Sem sincronização entre dispositivos, sem importação bancária, sem CSV de
  entrada e sem login remoto.
- A previsão usa apenas movimentos reais, compromissos conhecidos e histórico
  suficiente; não antecipa despesas não registadas e não é uma garantia.
- As recorrências materializam compromissos planeados, não movimentos
  realizados; o caixa só muda quando o compromisso é pago.
- O restauro substitui toda a base. Não há fusão de backups.
- Não há partilha integrada (share sheet). Os backups saem pelo seletor de
  gravação (*Guardar backup em…*) e os relatórios por *Guardar CSV em…*; em
  Android 11 ou mais recente, os ficheiros já escritos na pasta da aplicação
  só saem por `adb pull`. As exportações continuam também na pasta `exports`.
  A importação por seletor de ficheiros está disponível.
- O backup automático do Android está desativado: a base não é copiada para a
  conta Google. A recuperação depende dos backups criados pelo utilizador.
- Não é possível abrir uma base criada por uma versão mais recente do esquema.
- O bloqueio ao abrir depende do bloqueio do telefone e é apenas uma barreira
  de interface: não cifra a base nem os backups, e não protege contra root ou
  acesso direto aos ficheiros. Sem credenciais no sistema, a aplicação abre com
  aviso.
- Os lembretes dependem da permissão de notificações e das políticas de
  bateria do sistema. Usam alarmes inexatos, pelo que a entrega pode atrasar,
  sobretudo em poupança de energia ou com a aplicação forçada a parar; nesse
  caso voltam a ser agendados quando a aplicação abre ou o telefone reinicia.

## Atualização

1. Faça um backup antes de atualizar.
2. Instale o novo APK sobre o anterior, com a mesma assinatura.
3. A base existente é migrada de forma incremental (v1→v4) sem ser recriada.
   As migrações são aditivas e preservam os dados; a versão do esquema fica em
   `PRAGMA user_version` e em `schema_migrations`.
4. Abrir uma base mais recente com uma app antiga não é suportado.

Se a assinatura mudar (por exemplo, de debug para release), o Android recusa a
atualização. Desinstalar apaga a base privada da app: exporte o backup e
restaure-o depois de instalar a versão assinada.

## Assinatura de release

1. Crie um keystore (guarde-o e às palavras-passe em local seguro, fora do
   repositório):

   ```bash
   keytool -genkey -v -keystore android/financas-release.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias financas-release
   ```

2. Copie `android/key.properties.example` para `android/key.properties` e
   preencha os valores. `storeFile` é relativo a `android/app`.
3. Confirme que `android/key.properties`, `*.jks` e `*.keystore` estão
   ignorados pelo Git.
4. Gere o APK:

   ```bash
   flutter build apk --release
   apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
   ```

Nunca embuta credenciais no código, no APK ou no repositório.

## Resolução de problemas

- **A app não abre a base**: aparece uma mensagem com *Tentar novamente*. Não
  apague dados manualmente; consulte os caminhos em Definições e restaure um
  backup válido.
- **Backup inválido**: a app indica o motivo (JSON inválido, esquema
  incompatível, contagens ou relações inconsistentes) e não permite restaurar.
- **Saldo inesperado**: confirme a data de referência, contas arquivadas,
  moeda da conta, movimentos eliminados e pagamentos de compromissos/dívidas.
- **Previsão vazia**: sem compromissos e sem histórico suficiente, a projeção
  reflete apenas o saldo atual. Isso é esperado.
