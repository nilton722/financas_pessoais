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
- O backup automático do Android está desativado (`android:allowBackup="false"`):
  o sistema não copia a base SQLite nem as preferências para a conta Google.
  Alguns fabricantes podem manter a migração direta entre telefones durante a
  configuração; essa cópia é feita pelo sistema e não pode ser impedida pela
  app.

Flutter, Drift/SQLite, `path_provider` e `cryptography` são bibliotecas locais;
não enviam dados por si. O `cryptography` executa o PBKDF2 e o AES-256-GCM em
Dart dentro da aplicação, sem chamadas de rede. O utilizador pode, por ação
própria, copiar backups ou exportações para fora do dispositivo. Os botões
**Guardar backup em…** e **Guardar CSV em…** abrem o seletor de gravação do
sistema; se o utilizador escolher um serviço de nuvem (Google Drive, OneDrive,
etc.), é esse serviço, com a conta e as regras do utilizador, que recebe e
sincroniza o ficheiro. A aplicação não tem permissão `INTERNET` no release e
não participa nessa transferência.

## O que é guardado

- Contas (nome, tipo, moeda, saldo inicial e data), categorias, movimentos,
  compromissos, recorrências, orçamentos, metas e dívidas.
- Configurações locais de moeda, idioma e fuso horário.
- A preferência de bloqueio ao abrir (`lock_on_open`). É apenas um valor
  booleano: a aplicação não guarda PIN, padrão, palavra-passe nem dados
  biométricos.
- A preferência de lembretes (`reminders_enabled` e `reminder_time`) e as
  notificações pendentes agendadas no sistema. O sistema guarda o identificador,
  a data/hora e o texto do aviso (descrição, montante e conta) até o entregar ou
  ser cancelado.
- Timestamps técnicos de criação e atualização.
- A frase-passe dos backups **não é guardada**. Existe apenas nos campos da
  janela de criação/abertura, em memória, e não é escrita na base, nas
  preferências nem no ficheiro. Num backup cifrado ficam apenas o sal, o nonce,
  o número de iterações e o conteúdo cifrado.
- Não são guardadas credenciais bancárias, números de cartão, contactos,
  localização, microfone, câmara nem identificadores de publicidade.

## Permissões móveis

O manifesto principal (`android/app/src/main/AndroidManifest.xml`) declara
apenas permissões normais e de execução necessárias às funções locais:
`USE_BIOMETRIC`, para pedir ao sistema o desbloqueio do telefone;
`POST_NOTIFICATIONS`, pedida só ao ativar os lembretes; e
`RECEIVE_BOOT_COMPLETED`, para o sistema voltar a agendar os lembretes depois de
reiniciar o telefone. Os plugins acrescentam, na fusão do manifesto,
`VIBRATE` (vibração das notificações) e a permissão legada `USE_FINGERPRINT`,
sinónimo antigo de `USE_BIOMETRIC`; nenhuma destas recebe dados. A aplicação não
recebe biometria nem credenciais, apenas o resultado da verificação feita pelo
Android/iOS. Não são declaradas permissões de armazenamento, localização,
contactos, câmara ou microfone. As variantes `debug` e `profile` acrescentam
apenas `INTERNET`, exigida pelo Flutter para hot reload e depuração; a variante
**release** não a inclui. Os backups e exportações são escritos na pasta externa
específica da aplicação (`Android/data/<pacote>/files`), que não exige permissão
e é removida com a desinstalação. A exportação é sempre iniciada pelo
utilizador.

A importação de backups usa o seletor de documentos do sistema (Storage Access
Framework no Android, `UIDocumentPicker` no iOS) através do plugin oficial
`file_selector`. A gravação de backups e de relatórios fora da pasta usa o
mesmo mecanismo (`ACTION_CREATE_DOCUMENT` no Android) através do `file_picker`.
Em todos os casos, o utilizador autoriza apenas o ficheiro escolhido; a
aplicação não recebe acesso a pastas nem pede permissões de armazenamento, e
nenhum dos plugins faz chamadas de rede.

Os lembretes usam `flutter_local_notifications` e a base de fusos `timezone`
para agendar avisos no próprio aparelho. Não há serviço de push nem ligação de
rede. O Android guarda as notificações pendentes no AlarmManager e pode mostrar
o título e o corpo no ecrã de bloqueio; a aplicação marca-as como privadas no
Android, mas as pré-visualizações são controladas pelas definições do sistema.
No iOS, a permissão e as pré-visualizações seguem as definições do utilizador.

## Proteção local e limitações

- A base SQLite e as exportações CSV **não são cifradas**. Quem tiver acesso
  físico aos ficheiros (por exemplo, num dispositivo desbloqueado ou com root)
  consegue lê-los.
- Os backups podem ser **cifrados com frase-passe** (AES-256-GCM, chave derivada
  por PBKDF2-HMAC-SHA256 com sal aleatório) ou simples e legíveis. As cópias
  automáticas `pre-restore-…json` são simples e ficam na pasta privada da
  aplicação. A frase-passe não é guardada e não existe recuperação se for
  esquecida.
- Um backup **simples** guardado num serviço de nuvem fica legível para quem
  tiver acesso a esse ficheiro na conta. Um backup cifrado não é legível sem a
  frase-passe, mas o fornecedor continua a ver nome, tamanho e datas. A escolha
  do destino e a proteção da conta são responsabilidade do utilizador; a
  aplicação não controla retenção, versões nem sincronização do fornecedor.
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
- O checksum dos backups simples deteta corrupção acidental, não é uma
  assinatura criptográfica e não impede uma edição intencional. Nos backups
  cifrados, o AES-GCM autentica o conteúdo e o cabeçalho; uma alteração impede
  a abertura, mas não identifica o autor.
- A resistência da frase-passe depende da sua qualidade. Um atacante com o
  ficheiro pode tentar frases offline; use uma frase longa e única. Durante a
  criação ou o restauro, o JSON decifrado existe temporariamente na memória da
  aplicação.
- Os lembretes revelam descrição, montante e conta no texto da notificação. O
  conteúdo pode aparecer no ecrã de bloqueio e em notificações do sistema;
  desligue as pré-visualizações ou os lembretes se essa exposição não for
  aceitável.

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
