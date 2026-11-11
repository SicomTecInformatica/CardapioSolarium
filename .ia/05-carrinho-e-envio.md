# Parte 5 — Carrinho e envio do pedido

Cole esta mensagem inteira num chat novo. O workspace é `cardapio_solarium_flutter`.

Não altere o NSBasic nem a ApiCardapio. Não implemente a conta nem o pagamento. A barra “Ver pedido” deixa o placeholder e abre esta tela. O envio é `POST {IpApiCardapio}pedido`, sem PHP.

## Objetivo

Tela de pedido no padrão Goomer e envio no JSON que o `PedidoController` já recebe do Sicom Comanda.

## Tela

Rota `/pedido`. Cabeçalho com voltar e título “Pedido”. Sem logo grande.

Lista:

- Foto 72 px, nome, observações não vazias em 13 px `#6B6B6B` separadas por “ · ”.
- Preço da linha (unitário × quantidade) à direita.
- “−” quantidade “+”, 44 px. Em quantidade 1, “−” pede “Remover {nome}?” Sim / Não.
- Carrinho vazio: ilustração simples ou ícone, “Seu pedido está vazio” e botão “Ver cardápio”. A barra flutuante some.

Rodapé fixo:

- “Limpar”, texto, pede confirmação “Limpar o pedido?”. Sim esvazia e volta ao cardápio. Mantém o título.
- Total em destaque.
- Botão “Enviar pedido”, largura toda, 52 px, cor primária. Total zero não chega aqui porque o carrinho vazio não mostra o botão.

Não mostrar “1 Item      30,00” com espaços.

## Envio

Toque pede “Enviar o pedido?” Sim / Não.

Antes do POST, a mesma checagem de `TempoExpira` da parte 2. Expirado: não envia.

`POST pedido` com `Content-Type: application/json`, corpo único, como no contrato do `00-como-usar.md`:

`MesaH`:

- `Hdm_setor` e `Hdm_codlocal`: local do QR, número
- `Hdm_nummesa`: mesa do QR, número
- `Hdm_pdv` e `Hdm_pdvl`: 9999
- `Hdm_Local`: posição da sessão, número
- `Hdm_MaqFec`: `CELULAR`
- `Hdm_Socio`: título, string
- `Hdm_garcon`: 0
- `Hdm_NomeGarcom`: `""`
- `Hdm_IdPessoa`: id do sócio em string; `"0"` se for 0

`mesaItens`, um objeto por linha:

- `itm_mesa`: mesa do QR
- `itm_posicao`: posição da sessão
- `itm_socio`: título
- `itm_idsocio`: o mesmo valor de `Hdm_IdPessoa`
- `itm_produto`, `itm_descricao`, `itm_quantidade`
- `itm_vlrunit`: preço unitário
- `itm_valor`: unitário × quantidade
- `itm_observacao1`…`itm_observacao5` sempre presentes. Vazio é `""`

Números com ponto. Sem `|`, sem aspas simples e sem os nomes `hsetor`, `prd` ou `obs1`.

Enquanto envia, o botão fica em progresso e não aceita outro toque.

## Resposta

HTTP diferente de 200, ou falha de rede: “Não foi possível enviar. Tente de novo.” O carrinho permanece.

HTTP 200:

- Corpo vazio: sucesso.
- Depois de remover aspas e quebras de linha, se começar com `OK|`: ler a posição em `POSICAO=` e gravar na sessão. Sucesso.
- JSON `Message` igual a `Mesa se encontra fechada.`, `Mesa se encontra aberta em outro sócio.` ou `Socio já esta logado em outra mesa.`: diálogo com essa frase, esvaziar o carrinho, manter o título, voltar ao cardápio.
- `Message` começando com `Mesa se encontra fechada.` ou com `Erro ao gravar pedido. Violação da restrição PRIMARY KEY 'PK_MESAH'`: diálogo “Mesa se encontra fechada.”, esvaziar o carrinho, manter o título, voltar ao cardápio.
- Qualquer outro texto: diálogo com o texto recebido, carrinho permanece.

Sucesso: snackbar “Pedido enviado” e, se a posição veio no `OK|`, “Pedido enviado · posição {n}”. Esvaziar o carrinho, manter o título, voltar ao cardápio. Atualizar “Posição n” no cabeçalho.

## Pronto quando

- A barra flutuante abre esta tela e o total bate com as linhas.
- “−” em quantidade 1 remove só depois do sim; “+” e “−” recalculam a linha e o total.
- Um teste de unidade gera o mapa de duas linhas, uma com observação e outra sem, e confere `Hdm_Local` e `itm_posicao` como a posição, `itm_mesa` como a mesa, e `itm_observacao1`…`itm_observacao5` presentes.
- O teste do parser cobre corpo vazio, `OK|POSICAO=4`, as três `Message` conhecidas e a de chave primária.
- Nenhuma URL aponta para `Https_APIPostCardapio.php`.
