# Parte 4 — Detalhe do produto e observações

Cole esta mensagem inteira num chat novo. O workspace é `cardapio_solarium_flutter`.

Não altere o NSBasic nem a ApiCardapio. O GET de observações sai direto de `IpApiCardapio`. Não envie o pedido. O carrinho continua local.

## Objetivo

Abrir o produto num bottom sheet no padrão Goomer: foto, ingredientes, alergênicos, quantidade, observações em chips e botão fixo “Adicionar · R$ …”. O “+” do card, feito na parte 3, continua adicionando 1 unidade sem observação.

## Abrir o sheet

Toque no card, fora do “+”, abre o sheet. Arrastar para baixo ou tocar fora fecha sem incluir.

`GET Observacao/{codigoGrupo}` na primeira abertura de um produto daquele grupo; cache pelo grupo. Lista vazia ou corpo de “não encontrado”: não mostrar chips, só o campo livre. Falha de rede: sheet abre assim mesmo, com o campo livre e um texto “Observações prontas indisponíveis”.

## Conteúdo

De cima para baixo:

- Alça de arraste.
- Foto em largura total, 200 px, `BoxFit.cover`. Sem foto, faixa `#EEEEEE`.
- Nome, 20 px, peso 600.
- Preço unitário, 16 px.
- Ingredientes, 14 px, `#555555`, quantas linhas precisarem. Some se vazio.
- Linha de informações, só ícone + texto curto, o que for verdadeiro ou sempre no caso das kcal:
  - glúten: “Contém glúten” ou “Sem glúten”. A palavra é glúten, com acento.
  - lactose: “Contém lactose” ou “Sem lactose”.
  - vegano: mostrar só quando for vegano, texto “Vegano”.
  - kcal: “{n} kcal” quando o valor vier preenchido e não for zero.
- “Observações”, se houver chips. Cada `obs_descricao` é um chip de toque, 40 px de altura. Selecionado: fundo primário, texto branco. No máximo 5. A sexta tentativa explica “Limite de 5 observações por item.”
- Campo “Alguma observação?”, uma linha, no máximo 50 caracteres, contador `0/50`. Enter ou o botão Incluir trata o texto:
  - vazio: ignora;
  - igual a um chip, sem diferenciar maiúsculas: seleciona esse chip se ainda couber;
  - igual a um já selecionado: “Observação já incluída.” e limpa o campo;
  - texto novo: vira mais uma observação selecionada, se couber nas 5.
- Quantidade: “−” e “+” de 44 px. Mínimo 1. O preço do botão acompanha quantidade × unitário.
- Botão grudado no rodapé do sheet, acima do teclado: “Adicionar · R$ {total}”.

O teclado não pode cobrir o campo nem o botão. O sheet sobe.

## Carrinho local

Cada inclusão é uma linha se o código ou a lista de observações forem diferentes. Se código e as observações (as mesmas, na mesma ordem) já existirem, somar a quantidade na linha existente.

Ordem das observações na linha: chips selecionados na ordem em que foram tocados e, por último, o texto livre se não tiver sido absorvido por um chip. No máximo 5. Guardar as sobras como string vazia até completar 5, porque o POST da parte 5 manda `itm_observacao1`…`itm_observacao5`.

Teto de 25 linhas. Na tentativa de criar a 26ª: “Envie o pedido antes de incluir mais itens.” Somar quantidade numa linha que já existe não conta como linha nova.

Snackbar “Adicionado ao pedido”. A barra flutuante da parte 3 atualiza na hora.

Desfazer da parte 3 continua válido para o “+” rápido. O sheet não precisa de desfazer; fechar sem Adicionar não inclui.

## Pronto quando

- Card abre o sheet; “+” não abre.
- Dá para escolher 5 observações, misturando chip e texto de 50 caracteres, e a sexta é recusada.
- O botão mostra o valor da quantidade.
- Duas inclusões do mesmo produto com as mesmas observações viram uma linha só; observações diferentes viram linhas diferentes.
- `flutter analyze` limpo nos arquivos novos. Teste puro: montar as 5 observações e fundir linhas iguais.
