# Privacidade e proteção local

A aplicação é de uso individual e funciona offline. Esta página descreve o que
é guardado, o que nunca sai do dispositivo e quais são as limitações de
proteção nesta versão.

## Dados apenas no dispositivo

- Não há backend, login remoto, sincronização nem contas na nuvem.
- A aplicação não faz chamadas de rede no fluxo principal e funciona em modo
  avião depois de instalada.
- Não usa analytics, anúncios, telemetria, rastreio nem relatórios de falhas
  externos.
- Os dados financeiros nunca são transmitidos pela aplicação.

Flutter, Drift/SQLite e `path_provider` são bibliotecas locais; não enviam dados
por si. O utilizador pode, por ação própria, copiar backups ou exportações para
fora do dispositivo (USB, cartão, armazenamento escolhido) — essa cópia é feita
fora da aplicação.

## O que é guardado

- Contas (nome, tipo, moeda, saldo inicial e data), categorias, movimentos,
  compromissos, recorrências, orçamentos, metas e dívidas.
- Configurações locais de moeda, idioma e fuso horário.
- Timestamps técnicos de criação e atualização.
- Não são guardadas credenciais bancárias, números de cartão, contactos,
  localização, microfone, câmara nem identificadores de publicidade.

## Permissões móveis

O manifesto principal (`android/app/src/main/AndroidManifest.xml`) não declara
permissões de armazenamento, localização, contactos ou câmara. As variantes
`debug` e `profile` acrescentam apenas `INTERNET`, exigida pelo Flutter para
hot reload e depuração; a variante **release** não a inclui. Os backups e
exportações são escritos na pasta externa específica da aplicação
(`Android/data/<pacote>/files`), que não exige permissão e é removida com a
desinstalação. A exportação é sempre iniciada pelo utilizador.

## Proteção local e limitações

- A base SQLite, os backups e as exportações **não são cifrados**. Quem tiver
  acesso físico aos ficheiros (por exemplo, num dispositivo desbloqueado ou com
  root) consegue lê-los.
- Esta versão **não implementa PIN nem biometria**. Um eventual bloqueio de
  interface seria apenas uma barreira visual: não cifra a base nem os ficheiros.
- A proteção disponível é o bloqueio do sistema (PIN, padrão, biometria do
  Android) e a guarda das cópias fora do dispositivo.
- O checksum dos backups deteta corrupção acidental, não é uma assinatura
  criptográfica e não impede uma edição intencional.
- Se uma versão futura introduzir PIN ou biometria, usará APIs seguras da
  plataforma para o bloqueio de acesso; a limitação da base não cifrada será
  mantida explícita, salvo decisão documentada em contrário.

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
