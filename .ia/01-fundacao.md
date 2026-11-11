# Parte 1 — Fundação do app Flutter

Cole esta mensagem inteira num chat novo. O workspace é a pasta `Cardapio_Solarium`, pai de `CardapioSolarium.appstudio`.

## Objetivo

Criar o projeto Flutter Web que vai substituir só a interface. Nesta parte não há tela de cardápio, login funcional nem pedido. Há o esqueleto que as partes seguintes vão preencher: config, client HTTP direto na ApiCardapio, modelos, sessão em memória e um shell visual.

## Não fazer

- Não editar nada em `CardapioSolarium.appstudio` nem na ApiCardapio.
- Não criar tela de produto, carrinho, conta ou regra de sócio. Isso é das partes 2 a 6.
- Não passar pelos PHP `Https_API*.php`. O client chama `{IpApiCardapio}` direto, como o Sicom Comanda.
- Não usar `DioForNative`. No Web o cliente é o `Dio` do browser.
- Não adicionar backend, banco local ou autenticação nova.

## Onde criar

Projeto irmão do NSBasic:

```
Cardapio_Solarium/cardapio_solarium_flutter
```

Nome do pacote: `cardapio_solarium`. App: `Solarium Cardápio`.

## Stack

- Flutter estável, Dart 3, Material 3.
- Alvo desta entrega: Web. O projeto pode compilar para outras plataformas, mas não há trabalho específico de loja.
- `go_router`, `flutter_riverpod`, `dio`, `intl`, `shared_preferences`.
- Sem GetX, sem Bloc, sem gerador de código além do que o próprio Flutter criar.

## Estrutura

```
lib/
  main.dart
  app.dart
  core/config/app_config.dart
  core/network/cardapio_api.dart
  core/session/app_session.dart
  core/theme/club_theme.dart
  core/format/money.dart
  shared/models/grupo.dart
  shared/models/produto.dart
  shared/models/observacao.dart
  shared/models/cart_line.dart
  shared/models/mesa_status.dart
  shared/models/conta.dart
assets/config/config_cardapio.json
```

## Config

Copiar `IpApiCardapio` de `CardapioSolarium.appstudio/includes/configCardapio.json` para `assets/config/config_cardapio.json`. Não copiar `IpPhp`: aquele endereço é a rede local e o proxy antigo. No lugar, gravar `BaseImagens` como `imagens/`. Acrescentar as chaves opcionais só para deixar o padrão explícito; ausência usa:

- `SemSenha`: `"0"`
- `TempoExpira`: `14400`
- `ExtProd`: `"jpg"`

`AppConfig.load()` lê o asset uma vez. `IpApiCardapio` termina com `/` depois da normalização. `BaseImagens` também. Se `BaseImagens` não começar com `http`, a URL da foto é a origem da página mais esse caminho.

## Client HTTP

Classe `CardapioApi` com um `Dio` cuja `baseUrl` é `IpApiCardapio`. Os métodos montam o caminho e decodificam o corpo. Ainda não são chamados por tela, mas têm teste do JSON e do caminho, sem rede.

Métodos, sem lógica de tela:

- `parametros(local)` → `GET setor/setorparametros/{local}`
- `setor(local)` → `GET setor/{local}`
- `cliente(titulo)` → `GET Cliente/{titulo}`
- `clienteSenha(titulo, senha)` → `GET Cliente/{titulo}/{senha}`
- `statusMesa(mesa, local, posicao, titulo)` → `GET MesaH/lermesahstatus/...`
- `statusMesaPosicao(mesa, local, titulo)` → `GET MesaH/lermesahstatusposicao/...`
- `mesaH(mesa, local, posicao, titulo)` → `GET MesaH/...`
- `grupos(local)` → `GET Grupo/{local}`
- `produtos(grupo, local)` → `GET produto/grupo/{grupo}/{local}`
- `observacoes(grupo)` → `GET Observacao/{grupo}`
- `mesaI(mesa, local, posicao, titulo)` → `GET MesaI/...`
- `enviarPedido(mesaH, itens)` → `POST pedido` com o JSON de `MesaH` + `mesaItens` do contrato em `prompts-flutter/00-como-usar.md`
- `enviarConta(mesaC)` → `POST mesac` com o objeto na raiz, nomes iguais ao `MesacModel.toMap()` do Sicom Comanda

Timeout de 20 segundos. HTTP diferente de 200 devolve erro de rede amigável, sem expor status cru na mensagem de UI. O corpo bruto fica disponível para a camada de regra, porque a API usa HTTP 200 também para texto de erro (`Título não encontrado.`, `Sem cadastro.`, `Mesa não encontrada.`, `[]`).

Foto: `{BaseImagens}produtos/{codigo}.{ExtProd}`.

Parser de `OK|POSICAO=n` numa função pura, coberta por teste: tira aspas e quebras, se começa com `OK|` devolve a posição, senão devolve nulo.

## Modelos

Campos do contrato, e mais nada. `fromJson` tolerante: número pode vir como número ou string; bool pode vir como bool ou `"true"`/`"false"`. Campo ausente vira vazio, zero ou falso, sem exceção.

`CartLine`: código, descrição, quantidade, valor unitário, até 5 observações. Total da linha é unitário × quantidade. Limite de 25 linhas fica na sessão, não no modelo.

## Sessão

`AppSession` (Riverpod) guarda: mesa, local, posição (inicia em 1), título, nome do sócio, id do sócio (0 se desconhecido), hora de entrada, taxa (10 até o tema carregar), flags `habilitaPosicao` e `nomePosicao`, carrinho.

Nesta parte a sessão só tem leitura e escrita. Quem preenche é a parte 2.

Persistir título e linhas do carrinho em `shared_preferences`, para sobreviver a um refresh, como o `localStorage` faz hoje. Não persistir senha.

## Tema e shell

`ClubTheme` com fallback: primária `#005495`, superfície branca, fundo da página `#F6F6F6`, texto `#222222`, texto secundário `#6B6B6B`, cartão branco, raio 12.

`BackGround` da API pode ser um CSS `linear-gradient`. Função pura: se achar dois hex no texto, vira `LinearGradient` vertical; senão, cor primária sólida. Não interpretar CSS genérico.

Fonte: usar `FontesGeral` como `fontFamily` se vier preenchida. Sem baixar fonte. Fallback Roboto.

Tela única desta parte, rota `/`: coluna central, texto “Solarium Cardápio” e, se a URL tiver query, a mesa e o local lidos. Serve para provar o parser do QR.

## QR

A URL real é `index.html?70&2`, sem nomes de parâmetro. Não usar `queryParameters`.

Ler a URL completa, cortar no `?`, separar por `&`. Primeiro número é a mesa, segundo é o local. Ignorar um terceiro valor: o app atual também ignora. Sem query, mesa e local ficam 0 e a tela diz “Leia o QR Code da mesa”.

Guardar mesa, local e hora de entrada assim que o app abrir, antes do router trocar de rota. Usar `usePathUrlStrategy` sem perder essa query.

## Pronto quando

- `flutter test` passa nos testes de parser de QR, de `OK|POSICAO=`, de dinheiro pt_BR e do JSON de `POST pedido` e `POST mesac` (comparar o mapa, sem rede). O pedido de teste tem `Hdm_Local` igual à posição, `itm_mesa`, `itm_posicao` e `itm_observacao1`…`itm_observacao5`.
- `flutter build web` conclui.
- Abrir em `?70&2` mostra mesa 70 e local 2. Abrir sem query mostra o aviso do QR.
- Nenhum arquivo do NSBasic foi modificado.
