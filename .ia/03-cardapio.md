# Parte 3 — Cardápio no padrão Goomer

Cole esta mensagem inteira num chat novo. O workspace é `cardapio_solarium_flutter`.

Não altere o NSBasic nem a ApiCardapio. Os GET saem direto de `IpApiCardapio`. Não faça o bottom sheet, o POST do pedido nem a conta. Pode deixar o carrinho em memória que a parte 4 vai passar a alimentar; se a parte 4 ainda não existe, o botão “+” só incrementa um contador local visível na barra, com produto e quantidade, sem observação.

## Objetivo

Uma única tela de cardápio, como o Goomer de mesa: busca, categorias grudadas e lista de produtos. O sócio não abre uma tela só de grupos e outra só de itens.

## Dados

`GET Grupo/{local}` → `codigoGrupo`, `descricaoGrupo`.

Para cada grupo, `GET produto/grupo/{codigoGrupo}/{local}` → `codigo`, `descricao`, `preco`, `ingredientes`, `contemGluten`, `contemLactose`, `vegano`, `kcal`.

Buscar os grupos primeiro e pintar os chips. Buscar os produtos em seguida, em paralelo, com limite de 4 requisições ao mesmo tempo para não disparar dezenas juntas. Cache em memória pelo par grupo+local enquanto a sessão não expirar. Puxar de novo ao entrar na tela se o cache tiver mais de 5 minutos.

Foto: `{BaseImagens}produtos/{codigo}.{ExtProd}`, `BoxFit.cover`. Falha de imagem: retângulo na cor `#EEEEEE`, sem ícone de erro quebrado.

Grupo sem produto: não mostrar o chip. Lista vazia no total: “Nenhum produto neste local.”

## Layout

AppBar já definida na parte 2, compacta. À direita, ícone de conta desabilitado ou apontando para um placeholder “Conta na próxima etapa”. Não colocar Pedido, Consulta, Pagamento e Sair na mesma barra.

Abaixo, campo de busca com fundo `#F2F2F2`, sem borda pesada, placeholder “Buscar no cardápio”, limpar com X. Filtra por nome e por ingredientes, sem acento e sem diferenciar maiúsculas.

Abaixo, chips horizontais, grudados no topo junto com a busca enquanto a lista rola (`SliverPersistentHeader` ou equivalente). Chip da categoria visível fica selecionado: fundo primário, texto branco. Os outros: fundo branco, borda `#E6E6E6`, texto `#333333`. Toque no chip rola até a seção. Rolar a lista atualiza o chip. Durante a busca, esconder os chips e mostrar só os resultados, com o nome da categoria pequeno acima de cada card.

Seções: título da categoria em 18 px, peso 600, e os cards. Um scroll só.

Card, altura confortável, fundo branco, separador `#EDEDED`:

- Foto 104×104, raio 10, à esquerda.
- Nome em até 2 linhas, 15 px, `#222222`.
- Ingredientes em 1 linha, 13 px, `#6B6B6B`. Some se vier vazio.
- Preço em 15 px, peso 600, `R$ 18,90`.
- Botão circular “+”, 44 px, cor primária, à direita. Toque adiciona 1 unidade daquele produto, sem observação, e mostra snackbar “Adicionado” com Desfazer. O toque no resto do card fica para o sheet da parte 4; até lá, o toque no card também adiciona 1.

Não usar seta de 28 px. Não usar tabela. Não mostrar descrição longa no card.

Barra flutuante, só se houver item no carrinho: “Ver pedido · {n} itens · R$ {total}”, 52 px, raio 28, margem 16, acima da área segura, cor primária, texto branco. Toque abre um placeholder “Carrinho na próxima etapa” que já lista código, nome, quantidade e total, para a parte 5 substituir. Quantidade 1 no texto vira “1 item”; no plural, “itens”.

## Carga e erro

Skeleton de 6 cards na primeira carga. Falha de um grupo: a seção mostra “Não foi possível carregar {categoria}” e Repetir só daquele grupo. Falha geral de rede na lista de grupos: tela de erro com Repetir.

Respeitar a expiração da sessão ao entrar na tela: o mesmo diálogo da parte 2, sem redirect externo.

## Fora desta parte

- Bottom sheet, glúten, lactose, vegano, kcal, observações.
- Envio à API.
- Juntar duas linhas do mesmo produto. Por enquanto cada “+” é uma linha, até 25. Na 26ª: snackbar “Envie o pedido antes de incluir mais itens.”

## Pronto quando

- Com sessão de teste (mesa, local e título já gravados), a tela mostra categorias reais e produtos com foto, nome, ingredientes e preço.
- Busca “agua” acha o produto mesmo se o cadastro estiver “ÁGUA”.
- Chip e scroll acompanham um ao outro.
- “+” atualiza a barra flutuante e Desfazer remove a linha.
- `flutter analyze` limpo nos arquivos novos.
