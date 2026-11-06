# Backup, exportação e recuperação

A aplicação guarda tudo no dispositivo. Este documento descreve onde estão os
ficheiros, como criar, guardar e restaurar um backup, como exportar um relatório
e o que fazer para recuperar dados. A aplicação não envia dados para servidores;
quando escolhe um destino externo no seletor do sistema, é o serviço escolhido
(por exemplo, Google Drive) que recebe o ficheiro.

## Onde ficam os dados

| Conteúdo | Localização |
|---|---|
| Base SQLite | Pasta de dados privada da aplicação (`financas_pessoais.sqlite`), no Android `/data/data/ao.gb.financas_pessoais/databases/` |
| Backups | `<pasta visível>/backups` |
| Exportações CSV | `<pasta visível>/exports` |

No Android, a pasta visível é a pasta externa específica da aplicação
(`/storage/emulated/0/Android/data/ao.gb.financas_pessoais/files`). Esta pasta
pertence à aplicação: não exige permissões de armazenamento e a app nunca pede
acesso global a ficheiros. No desktop, a raiz é a pasta de documentos. Os
caminhos exatos aparecem em **Definições → Onde estão os dados**, com botão para
copiar.

A partir do Android 11, `Android/data` fica oculta nos gestores de ficheiros e
na transferência USB (MTP). Para retirar ficheiros do telefone, use **Guardar
backup em…** (recomendado) ou `adb pull` com depuração USB ativa. Para trazer um
backup de outro dispositivo não é preciso escrever na pasta da aplicação: use
**Importar de um ficheiro** (ver abaixo), que autoriza apenas o ficheiro
escolhido.

A base SQLite fica na área privada da aplicação e não é acessível sem root. Os
backups podem ser criados cifrados (AES-256-GCM com frase-passe) ou simples e
legíveis; as exportações CSV são sempre legíveis. Os ficheiros ficam na pasta
visível ou no destino que o utilizador escolher.

O backup automático do Android está desativado (`android:allowBackup="false"`):
a base e as preferências não são copiadas para a conta Google. A única cópia
para recuperação é a que o utilizador cria com os botões da aplicação.

## Formato do backup

Há dois formatos, escolhidos em cada criação: **cifrado** (recomendado) ou
**simples**. Ambos usam um documento JSON UTF-8, não uma cópia binária do
SQLite. A aplicação reconhece automaticamente qual está a abrir.

### Backup simples

O documento é legível e contém os dados em claro:

```json
{
  "format": "financas_pessoais_backup",
  "formatVersion": 1,
  "schemaVersion": 4,
  "createdAt": "2026-10-30T16:15:32.744Z",
  "appVersion": "1.0.0",
  "settings": { "currency_code": "XOF", "locale": "pt_PT", "time_zone": "Africa/Bissau" },
  "counts": { "accounts": 1, "transactions": 4, "...": 0 },
  "tables": { "accounts": [ ... ], "transactions": [ ... ], "...": [] },
  "checksum": "b058281e"
}
```

Inclui as 12 tabelas de dados do utilizador (contas, categorias, configurações,
movimentos, compromissos e pagamentos, recorrências e ocorrências, orçamentos,
metas, dívidas e pagamentos) com os IDs e valores SQLite originais. A tabela
técnica `schema_migrations` fica de fora: descreve a migração da base, não o
conteúdo. O objeto `settings` pode incluir a preferência `lock_on_open`; se o
backup tiver sido criado com o bloqueio ativo, o restauro volta a pedir o
desbloqueio do telefone no dispositivo atual, com as credenciais locais. Também
inclui `reminders_enabled` e `reminder_time`: a preferência é restaurada, mas a
permissão de notificações continua a ser de cada telefone. Se o novo telefone
não autorizar notificações, nada é agendado e as definições mostram um aviso
até a permissão ser dada.

No backup simples, o `checksum` é FNV-1a de 32 bits sobre o conteúdo. Deteta
corrupção acidental (ficheiro truncado ou editado por engano), mas **não é uma
assinatura criptográfica** e não impede uma edição intencional. O ficheiro
fica legível para quem tiver acesso a ele.

### Backup cifrado

O conteúdo do backup simples é cifrado com **AES-256-GCM** e guardado dentro de
um envelope JSON. A chave de 256 bits deriva da frase-passe com
**PBKDF2-HMAC-SHA256** e um sal aleatório de 16 bytes por ficheiro, com 210 000
iterações. O nonce de 12 bytes é aleatório. O cabeçalho
(`format`, `formatVersion`, `cipher`, `kdf`, `iterations`, `salt` e `nonce`) é
autenticado como dados associados do GCM: alterá-lo invalida a decifragem.

```json
{
  "format": "financas_pessoais_backup_encrypted",
  "formatVersion": 1,
  "cipher": "AES-256-GCM",
  "kdf": "PBKDF2-HMAC-SHA256",
  "iterations": 210000,
  "salt": "…16 bytes em base64…",
  "nonce": "…12 bytes em base64…",
  "ciphertext": "…",
  "mac": "…16 bytes em base64…"
}
```

O envelope não expõe nomes, montantes, configurações nem o `createdAt`: os
metadados do ficheiro só aparecem depois de a frase-passe abrir o conteúdo. A
lista de backups mostra apenas o nome do ficheiro, a data do sistema de
ficheiros, o tamanho e a indicação de que está cifrado.

A frase-passe **não é guardada** em lado nenhum e não existe recuperação. Se
for esquecida, o ficheiro não pode ser aberto. A aplicação não usa a chave do
telefone nem o cofre do sistema, precisamente para que o backup possa ser
restaurado num telefone novo.

O restauro valida primeiro o envelope, deriva a chave, verifica a autenticação
GCM e só depois aplica ao JSON interno a mesma validação do backup simples
(formato, esquema, tipos, contagens e checksum). Uma frase errada, um
cabeçalho alterado e um ficheiro truncado produzem a mesma mensagem, para não
revelar qual dos casos falhou.

As cópias automáticas `pre-restore-…json` continuam a ser backups **simples**:
são criadas na pasta privada da aplicação, ao lado da base que também não é
cifrada, e existem para permitir reverter um restauro. Não são pensadas para
sair do dispositivo.

## Criar um backup

**Definições → Backup e restauração → Criar backup agora.** A aplicação pede
primeiro a proteção: **Cifrado** (predefinido) ou **Sem cifra**. No modo
cifrado, a frase-passe tem de ter pelo menos 8 caracteres e ser repetida; não é
guardada. Aviso: se a esquecer, o backup não pode ser recuperado.

A escrita só acontece por ação do utilizador e produz
`backup-AAAAMMDD-HHMMSS-SSS.json` na pasta `backups`. A lista mostra data,
número de registos, tamanho e integridade verificada para backups simples; para
os cifrados mostra um cadeado e o texto «Cifrado · frase-passe necessária».
Um backup simples inválido aparece marcado e não pode ser restaurado. Um ficheiro
cifrado só é validado depois de a frase-passe o abrir.

## Guardar fora do dispositivo

**Definições → Backup e restauração → Guardar backup em…** cria um backup novo
(com a mesma escolha de cifra) e abre imediatamente o seletor de gravação do
sistema, com o nome já preenchido.
O destino pode ser Downloads, um cartão SD, Google Drive, OneDrive ou outro
fornecedor instalado; a escolha é sempre do utilizador e pode ser cancelada.

No Android é usado o Storage Access Framework (`ACTION_CREATE_DOCUMENT`): a
aplicação escreve apenas no ficheiro escolhido e não recebe acesso a pastas nem
permissões de armazenamento. A aplicação não fala com a rede: se escolher um
serviço de nuvem, a transferência é feita pela aplicação desse serviço, com as
regras e a conta do utilizador. No desktop, o mesmo botão abre o diálogo de
gravação do sistema.

A cópia fica também na pasta local `backups`; se cancelar o seletor, essa cópia
local mantém-se e a aplicação informa que nada foi guardado fora do dispositivo.

## Restaurar

Num backup cifrado, a aplicação pede primeiro a frase-passe. O diálogo valida-a
sem fechar: uma frase errada mostra «Frase-passe incorreta ou ficheiro
alterado.» e permite tentar outra vez. Só depois de o envelope ser autenticado
é mostrada a pré-visualização.

Antes de tocar em **Restaurar**, a aplicação volta a ler e a validar o ficheiro:

1. envelope válido e autenticado, quando cifrado; JSON simples, quando não é;
2. `format` e `formatVersion` suportados;
3. `schemaVersion` exatamente igual à da aplicação (v4);
4. tipos de cada coluna, contagens por tabela e `checksum`.

A pré-visualização mostra a data de criação, versão da app e do esquema, total
de registos e o conteúdo por tabela. A confirmação avisa que a substituição não
pode ser anulada dentro da aplicação.

Ao confirmar:

1. é criada automaticamente uma cópia de segurança da base atual
   (`pre-restore-AAAAMMDD-HHMMSS-SSS.json`) na mesma pasta;
2. a substituição corre numa única transação SQLite — apaga pela ordem inversa
   das dependências, insere pela ordem pai → filho, confere as contagens e corre
   `PRAGMA foreign_key_check`;
3. se qualquer passo falhar, a transação é revertida e a base atual mantém-se
   intacta; a aplicação mostra a mensagem de erro sem expor dados financeiros.

Depois do restauro, os ecrãs recarregam os dados. IDs, relações e montantes são
preservados porque são restaurados a partir do documento, não reconstruídos.

## Importar um backup de outro dispositivo

**Definições → Backup e restauração → Importar de um ficheiro** abre o seletor
de documentos do sistema (Downloads, cartão SD, pasta escolhida). No Android é
usado o Storage Access Framework: o utilizador autoriza apenas o ficheiro
escolhido e a aplicação não recebe acesso a pastas nem pede permissões de
armazenamento.

Se o ficheiro for cifrado, a aplicação pede a frase-passe e autentica o envelope
antes de continuar. Depois, o conteúdo passa pela mesma validação do restauro
local (formato, versão, esquema, tipos, contagens e checksum). A
pré-visualização, a confirmação destrutiva, a cópia automática
`pre-restore-…json` e a transação atómica são idênticas. O ficheiro importado
não é copiado para a pasta `backups`: é restaurado diretamente e só a cópia de
segurança fica registada na lista. A cópia tem o formato simples, ainda que o
ficheiro importado fosse cifrado.

## Exportar um relatório

**Definições → Relatórios e exportação** (ou o ícone de relatórios no painel)
agrega os movimentos do período escolhido — este mês, mês anterior, últimos
três meses ou intervalo personalizado — por categoria ou por conta. O botão
**Exportar CSV** escreve `relatorio-AAAAMMDD-AAAAMMDD-<instante>.csv` na pasta
`exports`; **Guardar CSV em…** grava o mesmo ficheiro no destino escolhido no
seletor do sistema (Downloads, Drive, cartão SD), mantendo também a cópia local.
Cancelar o seletor não apaga a cópia em `exports` e a aplicação informa que
nada foi guardado fora.

O CSV usa UTF-8 com BOM, separador `;`, fim de linha CRLF, datas `DD/MM/YYYY`,
montantes inteiros em FCFA e rótulos em português; campos com `;`, aspas ou
quebras de linha ficam entre aspas duplas. Abre diretamente em folhas de
cálculo configuradas para português. Transferências aparecem listadas com conta
de destino, mas não contam como rendimento nem despesa. Movimentos eliminados
(na lixeira) ficam de fora. PDF fica para uma fase futura.

A **lixeira** guarda os movimentos eliminados com as respetivas afetações a
compromissos e dívidas, para que o restauro volte a ligá-los sem perder
pagamentos. O backup JSON inclui a coluna `deleted_at`, por isso um restauro
devolve também os movimentos que estavam na lixeira; no dispositivo restaurado
continuam a poder ser recuperados ou eliminados definitivamente.

## Copiar para fora do dispositivo

O backup e a exportação só protegem os dados se existir uma cópia fora do
telefone. Use **Guardar backup em…** para escolher Downloads, Google Drive,
OneDrive, um cartão SD ou outro destino no seletor do sistema. A aplicação não
faz upload nem sincronização: quem transfere o ficheiro para a nuvem é o serviço
escolhido, sujeito à conta e à política desse fornecedor.

No Android 11 ou mais recente, a pasta `Android/data` continua oculta nos
gestores de ficheiros e na transferência USB; para retirar os ficheiros já
escritos na pasta da aplicação, use `adb pull` (com depuração USB ativa):

```bash
adb pull /sdcard/Android/data/ao.gb.financas_pessoais/files/backups ./backups
adb pull /sdcard/Android/data/ao.gb.financas_pessoais/files/exports ./exports
```

Em versões anteriores, o gestor de ficheiros e a transferência USB funcionam
normalmente. Para repor um ficheiro não precisa de escrever na pasta da
aplicação: escolha-o em **Importar de um ficheiro**.

No Android, desinstalar a aplicação ou limpar os dados remove a base e a pasta
da aplicação, incluindo os backups locais. Faça um backup e copie-o antes de
desinstalar ou trocar de dispositivo.

## Recuperação

- **Restaurou o backup errado:** abra a lista de backups, escolha o ficheiro
  `pre-restore-…json` criado automaticamente e restaure-o. A cópia é um backup
  normal e validado.
- **Ficheiro corrompido ou de versão não suportada:** é recusado antes de
  qualquer alteração; os dados atuais ficam como estavam. Use outra cópia.
- **Esqueceu a frase-passe de um backup cifrado:** não há recuperação. A
  aplicação não guarda a frase nem uma chave alternativa. Use outro backup
  cifrado cuja frase tenha guardado, ou a cópia simples `pre-restore-…json` se
  esta existir no dispositivo.
- **Perdeu o dispositivo ou trocou de telefone:** só uma cópia externa permite
  recuperar. Instale a aplicação, abra-a uma vez e use **Definições → Backup e
  restauração → Importar de um ficheiro** para escolher o JSON (por exemplo, no
  Google Drive ou em Downloads). Não é necessário copiá-lo para a pasta da
  aplicação.
- **Relatório CSV:** pode ser aberto ou reimportado numa folha de cálculo sem a
  aplicação; não substitui o backup, porque não contém planeamento nem
  configurações.

## Limitações de proteção local

- A base SQLite **não é cifrada** e as exportações CSV são legíveis. Só os
  backups criados no modo cifrado protegem o conteúdo; os backups simples e as
  cópias automáticas `pre-restore-…json` continuam legíveis.
- Um backup cifrado guardado no Google Drive ou noutro serviço não é legível sem
  a frase-passe, mas os metadados do fornecedor (nome, tamanho, datas, versões)
  continuam visíveis. A frase-passe não é guardada na aplicação.
- O bloqueio opcional depende das credenciais do telefone e é uma barreira de
  interface; não cifra a base em uso.
- Num dispositivo desbloqueado ou com root, quem tiver acesso físico consegue
  ler a base e os ficheiros simples. A proteção disponível é o bloqueio do
  sistema, a cifra dos backups, a conta do fornecedor de nuvem e a guarda das
  cópias.
- O checksum do backup simples deteta corrupção acidental, não adulteração
  intencional. No backup cifrado, o GCM autentica o conteúdo e o cabeçalho; uma
  alteração impede a abertura, mas não identifica o autor.
- A frase-passe pode ser atacada por tentativa offline sobre o ficheiro; use uma
  frase longa e única. A aplicação limita o custo declarado no envelope para
  evitar parâmetros abusivos.
- O destino externo é escolhido no seletor do sistema; a aplicação não controla
  a retenção, as versões nem a sincronização feitas pelo fornecedor.

## Testes que cobrem este processo

`test/unit/backup/backup_crypto_test.dart`,
`test/unit/backup/backup_format_test.dart`,
`test/unit/backup/backup_service_test.dart`,
`test/unit/reports/report_test.dart`, `test/unit/reports/report_csv_test.dart`,
`test/widget/backup_flow_test.dart` e `test/widget/reports_flow_test.dart`.
Cobrem backup → restauro com comparação de dados, ficheiro corrompido, versão de
esquema não suportada, falha com reversão, importação de ficheiro externo
(válida e inválida), gravação no destino escolhido e cancelamento da gravação
(backup e CSV), CSV com acentos e separadores, estados vazios e confirmação.
Para a cifra: ida-e-volta com acentos, sal e nonce aleatórios, frase errada,
ciphertext/MAC/cabeçalho adulterados, envelopes incompletos, parâmetros
abusivos, distinção entre formatos, criação e restauro cifrados (local e
importado), compatibilidade com backups simples antigos e validação da
frase-passe na interface.
