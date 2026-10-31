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

A base SQLite fica na área privada da aplicação e não é acessível sem root; os
backups e exportações são cópias legíveis na pasta visível.

## Formato do backup

O backup é um documento JSON UTF-8 legível, não uma cópia binária do SQLite:

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
desbloqueio do telefone no dispositivo atual, com as credenciais locais.

O `checksum` é FNV-1a de 32 bits sobre o conteúdo. Deteta corrupção acidental
(ficheiro truncado ou editado por engano), mas **não é uma assinatura
criptográfica** e não impede uma edição intencional. O ficheiro não é cifrado.

## Criar um backup

**Definições → Backup e restauração → Criar backup agora.** A escrita só
acontece por ação do utilizador e produz `backup-AAAAMMDD-HHMMSS-SSS.json` na
pasta `backups`. A lista mostra data, número de registos, tamanho e integridade
verificada. Um backup inválido aparece marcado e não pode ser restaurado.

## Guardar fora do dispositivo

**Definições → Backup e restauração → Guardar backup em…** cria um backup novo e
abre imediatamente o seletor de gravação do sistema, com o nome já preenchido.
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

Antes de tocar em **Restaurar**, a aplicação volta a ler e a validar o ficheiro:

1. JSON válido e estrutura esperada;
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

O conteúdo passa pela mesma validação do restauro local (formato, versão,
esquema, tipos, contagens e checksum). A pré-visualização, a confirmação
destrutiva, a cópia automática `pre-restore-…json` e a transação atómica são
idênticas. O ficheiro importado não é copiado para a pasta `backups`: é
restaurado diretamente e só a cópia de segurança fica registada na lista.

## Exportar um relatório

**Definições → Relatórios e exportação** (ou o ícone de relatórios no painel)
agrega os movimentos do período escolhido — este mês, mês anterior, últimos
três meses ou intervalo personalizado — por categoria ou por conta. O botão
**Exportar CSV** escreve `relatorio-AAAAMMDD-AAAAMMDD-<instante>.csv` na pasta
`exports`.

O CSV usa UTF-8 com BOM, separador `;`, fim de linha CRLF, datas `DD/MM/YYYY`,
montantes inteiros em FCFA e rótulos em português; campos com `;`, aspas ou
quebras de linha ficam entre aspas duplas. Abre diretamente em folhas de
cálculo configuradas para português. Transferências aparecem listadas com conta
de destino, mas não contam como rendimento nem despesa. Movimentos eliminados
ficam de fora. PDF fica para uma fase futura.

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
- **Perdeu o dispositivo ou trocou de telefone:** só uma cópia externa permite
  recuperar. Instale a aplicação, abra-a uma vez e use **Definições → Backup e
  restauração → Importar de um ficheiro** para escolher o JSON (por exemplo, no
  Google Drive ou em Downloads). Não é necessário copiá-lo para a pasta da
  aplicação.
- **Relatório CSV:** pode ser aberto ou reimportado numa folha de cálculo sem a
  aplicação; não substitui o backup, porque não contém planeamento nem
  configurações.

## Limitações de proteção local

- A base SQLite, os backups e as exportações **não são cifrados**. Um backup
  guardado no Google Drive ou noutro serviço fica legível para quem tiver acesso
  a esse ficheiro na conta.
- A aplicação não tem PIN nem cifra a base; o bloqueio opcional depende das
  credenciais do telefone e é uma barreira de interface.
- Num dispositivo desbloqueado ou com root, quem tiver acesso físico consegue
  ler os ficheiros. A proteção disponível é o bloqueio do sistema, a conta do
  fornecedor de nuvem e a guarda das cópias.
- O checksum deteta corrupção acidental, não adulteração intencional.
- O destino externo é escolhido no seletor do sistema; a aplicação não controla
  a retenção, as versões nem a sincronização feitas pelo fornecedor.

## Testes que cobrem este processo

`test/unit/backup/backup_format_test.dart`,
`test/unit/backup/backup_service_test.dart`,
`test/unit/reports/report_test.dart`, `test/unit/reports/report_csv_test.dart`,
`test/widget/backup_flow_test.dart` e `test/widget/reports_flow_test.dart`.
Cobrem backup → restauro com comparação de dados, ficheiro corrompido, versão de
esquema não suportada, falha com reversão, importação de ficheiro externo
(válida e inválida), gravação no destino escolhido e cancelamento da gravação,
CSV com acentos e separadores, estados vazios e confirmação.
