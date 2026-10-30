# Backup, exportação e recuperação

A aplicação guarda tudo no dispositivo. Este documento descreve onde estão os
ficheiros, como criar e restaurar um backup, como exportar um relatório e o que
fazer para recuperar dados. Nada é enviado para servidores.

## Onde ficam os dados

| Conteúdo | Localização |
|---|---|
| Base SQLite | Pasta de dados privada da aplicação (`financas_pessoais.sqlite`), no Android `/data/data/ao.gb.financas_pessoais/databases/` |
| Backups | `<pasta visível>/backups` |
| Exportações CSV | `<pasta visível>/exports` |

No Android, a pasta visível é a pasta externa específica da aplicação
(`/storage/emulated/0/Android/data/ao.gb.financas_pessoais/files`). Não exige
permissões de armazenamento e pode ser copiada por USB ou por um gestor de
ficheiros. No desktop, a raiz é a pasta de documentos. Os caminhos exatos
aparecem em **Definições → Onde estão os dados**, com botão para copiar.

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
conteúdo.

O `checksum` é FNV-1a de 32 bits sobre o conteúdo. Deteta corrupção acidental
(ficheiro truncado ou editado por engano), mas **não é uma assinatura
criptográfica** e não impede uma edição intencional. O ficheiro não é cifrado.

## Criar um backup

**Definições → Backup e restauração → Criar backup agora.** A escrita só
acontece por ação do utilizador e produz `backup-AAAAMMDD-HHMMSS-SSS.json` na
pasta `backups`. A lista mostra data, número de registos, tamanho e integridade
verificada. Um backup inválido aparece marcado e não pode ser restaurado.

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
telefone. Depois de criar o ficheiro, copie-o por USB, cartão de memória ou pelo
serviço de armazenamento que preferir. A aplicação não faz upload nem
sincronização.

No Android, desinstalar a aplicação ou limpar os dados remove a base e a pasta
da aplicação, incluindo os backups locais. Faça um backup e copie-o antes de
desinstalar ou trocar de dispositivo.

## Recuperação

- **Restaurou o backup errado:** abra a lista de backups, escolha o ficheiro
  `pre-restore-…json` criado automaticamente e restaure-o. A cópia é um backup
  normal e validado.
- **Ficheiro corrompido ou de versão não suportada:** é recusado antes de
  qualquer alteração; os dados atuais ficam como estavam. Use outra cópia.
- **Perdeu o dispositivo:** só uma cópia externa permite recuperar. Instale a
  aplicação, abra-a uma vez (para criar a pasta de dados), copie o ficheiro
  para a pasta `backups` e use **Definições → Backup e restauração** para o
  restaurar.
- **Relatório CSV:** pode ser aberto ou reimportado numa folha de cálculo sem a
  aplicação; não substitui o backup, porque não contém planeamento nem
  configurações.

## Limitações de proteção local

- A base SQLite, os backups e as exportações **não são cifrados**.
- Esta versão **não tem PIN nem biometria**. Um bloqueio de interface seria uma
  barreira visual, não cifragem da base.
- Num dispositivo desbloqueado ou com root, quem tiver acesso físico consegue
  ler os ficheiros. A proteção disponível é o bloqueio do sistema e a guarda das
  cópias.
- O checksum deteta corrupção acidental, não adulteração intencional.

## Testes que cobrem este processo

`test/unit/backup/backup_format_test.dart`,
`test/unit/backup/backup_service_test.dart`,
`test/unit/reports/report_test.dart`, `test/unit/reports/report_csv_test.dart`,
`test/widget/backup_flow_test.dart` e `test/widget/reports_flow_test.dart`.
Cobrem backup → restauro com comparação de dados, ficheiro corrompido, versão de
esquema não suportada, falha com reversão, CSV com acentos e separadores,
estados vazios e confirmação.
