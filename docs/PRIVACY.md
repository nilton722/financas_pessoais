# Privacidade e proteção local

A aplicação é de uso individual e funciona offline. Esta página descreve o que
é guardado, o que nunca sai do dispositivo e quais são as limitações de
proteção nesta versão.

## Dados apenas no dispositivo

- Não há backend, login remoto, sincronização nem contas na nuvem geridas pela
  aplicação.
- A aplicação não faz chamadas de rede no fluxo principal e funciona em modo
  avião depois de instalada.
- Não usa analytics, anúncios, telemetria, rastreio nem relatórios de falhas
  externos.
- Os dados financeiros nunca são transmitidos pela aplicação.

Flutter, Drift/SQLite e `path_provider` são bibliotecas locais; não enviam dados
por si. O utilizador pode, por ação própria, copiar backups ou exportações para
fora do dispositivo. O botão **Guardar backup em…** abre o seletor de gravação
do sistema; se o utilizador escolher um serviço de nuvem (Google Drive,
OneDrive, etc.), é esse serviço, com a conta e as regras do utilizador, que
recebe e sincroniza o ficheiro. A aplicação não tem permissão `INTERNET` no
release e não participa nessa transferência.

## O que é guardado

- Contas (nome, tipo, moeda, saldo inicial e data), categorias, movimentos,
  compromissos, recorrências, orçamentos, metas e dívidas.
- Configurações locais de moeda, idioma e fuso horário.
- A preferência de bloqueio ao abrir (`lock_on_open`). É apenas um valor
  booleano: a aplicação não guarda PIN, padrão, palavra-passe nem dados
  biométricos.
- Timestamps técnicos de criação e atualização.
- Não são guardadas credenciais bancárias, números de cartão, contactos,
  localização, microfone, câmara nem identificadores de publicidade.

## Permissões móveis

O manifesto principal (`android/app/src/main/AndroidManifest.xml`) declara
apenas a permissão normal `USE_BIOMETRIC`, necessária para pedir ao sistema o
desbloqueio do telefone. Não é uma permissão de dados: a aplicação não recebe
biometria nem credenciais, apenas o resultado da verificação feita pelo
Android/iOS. Não são declaradas permissões de armazenamento, localização,
contactos ou câmara. As variantes `debug` e `profile` acrescentam apenas
`INTERNET`, exigida pelo Flutter para hot reload e depuração; a variante
**release** não a inclui. Os backups e exportações são escritos na pasta externa
específica da aplicação (`Android/data/<pacote>/files`), que não exige permissão
e é removida com a desinstalação. A exportação é sempre iniciada pelo
utilizador.

A importação de backups usa o seletor de documentos do sistema (Storage Access
Framework no Android, `UIDocumentPicker` no iOS) através do plugin oficial
`file_selector`. A gravação de backups fora da pasta usa o mesmo mecanismo
(`ACTION_CREATE_DOCUMENT` no Android) através do `file_picker`. Em ambos os
casos, o utilizador autoriza apenas o ficheiro escolhido; a aplicação não
recebe acesso a pastas nem pede permissões de armazenamento, e nenhum dos
plugins faz chamadas de rede.

## Proteção local e limitações

- A base SQLite, os backups e as exportações **não são cifrados**. Quem tiver
  acesso físico aos ficheiros (por exemplo, num dispositivo desbloqueado ou com
  root) consegue lê-los.
- Um backup guardado num serviço de nuvem fica legível para quem tiver acesso a
  esse ficheiro na conta do fornecedor. A escolha do destino e a proteção da
  conta são responsabilidade do utilizador; a aplicação não controla retenção,
  versões nem sincronização do fornecedor.
- O bloqueio ao abrir é **opcional** e usa o PIN, padrão, palavra-passe ou
  biometria do telefone através das APIs do sistema (`local_auth`). É uma
  barreira de interface: impede ver a aplicação sem desbloquear o telefone, mas
  **não cifra** a base nem os ficheiros. A aplicação volta a pedir o
  desbloqueio após 60 segundos em segundo plano.
- A verificação biométrica é feita pelo Android/iOS. A aplicação não recebe nem
  guarda dados biométricos; só sabe se a autenticação foi confirmada.
- Se o telefone não tiver credenciais configuradas, a aplicação explica a
  situação e permite abrir sem bloqueio, para não ficar inacessível.
- A proteção disponível continua a ser o bloqueio do sistema (PIN, padrão,
  biometria do Android) e a guarda das cópias fora do dispositivo.
- O checksum dos backups deteta corrupção acidental, não é uma assinatura
  criptográfica e não impede uma edição intencional.

## Logs e mensagens

A aplicação não regista valores financeiros em logs. As falhas de leitura,
validação ou restauro são apresentadas como mensagens genéricas (por exemplo,
"O backup está corrompido: o checksum não confere.") sem expor montantes,
descrições ou nomes de terceiros.

## Relatórios e previsão

- A exportação CSV é criada localmente e só por ação do utilizador.
- A previsão é um cálculo determinístico local. É uma estimativa, não uma
  garantia; o ecrã mostra data de corte, horizonte, pressupostos, qualidade dos
  dados e limitações (ADR-026 e ADR-027).

## Onde saber mais

Localização dos ficheiros, formato do backup e passos de recuperação estão em
[BACKUP.md](BACKUP.md).
