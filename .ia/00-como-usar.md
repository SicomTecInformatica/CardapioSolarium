# Como usar estes prompts

Estes arquivos convertem o Cardápio Solarium (NSBasic/AppStudio) para um PWA Flutter no padrão visual do Goomer de mesa. Cada arquivo é a mensagem inteira de um chat novo.

Não altere o projeto NSBasic nem a ApiCardapio. O app novo consome a API direto, como o Sicom Comanda. Não use os PHP `Https_APIGet.php`, `Https_APIPostCardapio.php` nem `Https_APIPostCardapioMesaC.php`.

## Ordem

Abra um chat novo para cada parte, com a pasta do trabalho aberta. Cole o arquivo inteiro como primeira mensagem. Espere a parte terminar e ser revisada antes da próxima.

| Parte | Arquivo | O que entrega | Workspace do chat |
|---|---|---|---|
| 1 | `01-fundacao.md` | Projeto Flutter, config, client HTTP, modelos, tema vazio | Pasta pai `Cardapio_Solarium` |
| 2 | `02-login-e-regras-de-mesa.md` | QR, tema do clube, login do sócio, regras de mesa | `cardapio_solarium_flutter` |
| 3 | `03-cardapio.md` | Cardápio em uma tela, busca, chips, cards | `cardapio_solarium_flutter` |
| 4 | `04-produto-e-observacoes.md` | Bottom sheet, alergênicos, observações, carrinho local | `cardapio_solarium_flutter` |
| 5 | `05-carrinho-e-envio.md` | Barra flutuante, tela do pedido, POST pedido | `cardapio_solarium_flutter` |
| 6 | `06-conta-e-pagamento.md` | Conta da mesa e POST MesaC | `cardapio_solarium_flutter` |
| 7 | `07-pwa-e-aceite.md` | PWA, expiração da sessão, revisão contra o app atual | `cardapio_solarium_flutter` |

A parte 1 cria `Cardapio_Solarium/cardapio_solarium_flutter`, irmão de `CardapioSolarium.appstudio`. A partir da parte 2, abra essa pasta como workspace.

## Regras que valem em todas as partes

- Interface em português do Brasil.
- Celular primeiro. No desktop, coluna central de no máximo 480 px.
- Alvo de toque mínimo de 44 px.
- Não inventar endpoint, campo ou regra de negócio.
- Não “corrigir” mesa versus posição. Há comparação histórica em que o campo `posicao` do status é comparado com o número da mesa. Reproduzir como está documentado na parte 2.
- Não copiar hacks de layout do NSBasic (tabela HTML, `MsgBox` técnico, painel em `Top = 21%`, bloqueio de clique de 450 ms, preço alinhado com espaços, fonte cravada na célula).
- Não copiar estes bugs: observação 1 lida sem o índice do item no envio; `Mcl_Valor` montado apagando a vírgula; redirecionamento para URL de homologação quando a sessão expira.
- Sucesso vira snackbar. Bloqueio de negócio (mesa fechada, senha inválida, outro sócio) vira diálogo curto. Erro de rede vira “Sem conexão. Tente de novo.” com botão de repetir. Nunca mostrar `Error: Status`.
- Dinheiro: número JSON com ponto; na tela, `R$` e vírgula, duas casas, `NumberFormat` pt_BR. Sem preencher com espaços.
- O app atual continua no ar. Este Flutter não substitui o deploy do NSBasic.

## Contrato da API (referência única)

O PWA fala com a ApiCardapio por HTTPS, com `Dio` do browser. Não use `DioForNative`: isso é o cliente do aplicativo de celular. A API já responde com CORS `AllowAnyOrigin`, `AllowAnyHeader` e `AllowAnyMethod`, que é o que o Sicom Comanda usa.

Base lida de `assets/config/config_cardapio.json`:

- `IpApiCardapio` — ex.: `https://cardapiosicom.azurewebsites.net/api/v1/`
- `BaseImagens` — pasta pública das fotos, no mesmo site do PWA. Ex.: `imagens/`. Caminho relativo resolve na origem da página. Não usar o `IpPhp` da rede local (`192.168.x`): o celular do sócio não alcança esse IP.
- `SemSenha` — opcional, padrão `"0"`
- `TempoExpira` — opcional, segundos, padrão `14400`
- `ExtProd` — opcional, padrão `jpg`

O deploy do PWA sobe por FTP em `ftp.sicomtec.com.br`, numa pasta própria, servida em HTTPS. Não publicar por cima do cardápio NSBasic.

GET e POST vão direto em `{IpApiCardapio}...`, com `Content-Type: application/json` no POST. Sem query string montada, sem `|` entre itens, sem aspas simples.

POST `{api}pedido`, no formato de `Sicom_Comanda/lib/app/repositories/order/order_repository_impl.dart`. `Hdm_Local` é a posição, não o setor. `Hdm_setor` e `Hdm_codlocal` são o local do QR. No cardápio do sócio, `Hdm_pdv` e `Hdm_pdvl` são 9999 e `Hdm_MaqFec` é `CELULAR`. `Hdm_Socio` é o título. `Hdm_IdPessoa` é o `id_socio` em string, ou `"0"`. `Hdm_garcon` é 0. A API grava a mesa pela dupla `itm_mesa` + `itm_posicao` de cada item; esses dois campos são obrigatórios.

```json
{
  "MesaH": {
    "Hdm_setor": 2,
    "Hdm_nummesa": 70,
    "Hdm_codlocal": 2,
    "Hdm_pdv": 9999,
    "Hdm_Local": 1,
    "Hdm_pdvl": 9999,
    "Hdm_MaqFec": "CELULAR",
    "Hdm_Socio": "12345",
    "Hdm_garcon": 0,
    "Hdm_NomeGarcom": "",
    "Hdm_IdPessoa": "99"
  },
  "mesaItens": [
    {
      "itm_mesa": 70,
      "itm_posicao": 1,
      "itm_socio": "12345",
      "itm_idsocio": "99",
      "itm_produto": 22001,
      "itm_descricao": "AGUA",
      "itm_quantidade": 1,
      "itm_vlrunit": 4.0,
      "itm_valor": 4.0,
      "itm_observacao1": "",
      "itm_observacao2": "",
      "itm_observacao3": "",
      "itm_observacao4": "",
      "itm_observacao5": ""
    }
  ]
}
```

Não enviar os nomes curtos do NSBasic (`hsetor`, `prd`, `obs1`). O `PedidoController` vincula `Hdm_*` e `itm_*`.

POST `{api}mesac`, objeto na raiz, como `MesacModel.toMap()` do Sicom Comanda. `mcl_Valor` é número JSON com ponto, duas casas: consumido × (1 + taxa/100). `rec_codsat` vai `"0"`.

```json
{
  "mcl_setor": 2,
  "mcl_nummesa": 70,
  "mcl_Cliente": 12345,
  "mcl_NomeCliente": "Nome do sócio",
  "mcl_IdSocio": 99,
  "mcl_Valor": 52.8,
  "mcl_CancServico": 0,
  "mcl_NumFecConta": 0,
  "mcl_vrtxservico": 0,
  "rec_codsat": "0",
  "mcl_Posicao": 1
}
```

### Endpoints GET

| Uso | URL |
|---|---|
| Tema | `{api}setor/setorparametros/{local}` |
| Nome do setor | `{api}setor/{local}` |
| Sócio | `{api}Cliente/{titulo}` |
| Senha | `{api}Cliente/{titulo}/{senha}` |
| Status da mesa | `{api}MesaH/lermesahstatus/{mesa}/{local}/{posicao}/{titulo}` |
| Status quando posição é mesa | `{api}MesaH/lermesahstatusposicao/{mesa}/{local}/{titulo}` |
| Cabeçalho da conta | `{api}MesaH/{mesa}/{local}/{posicao}/{titulo}` |
| Grupos | `{api}Grupo/{local}` |
| Produtos | `{api}produto/grupo/{codigoGrupo}/{local}` |
| Observações | `{api}Observacao/{codigoGrupo}` |
| Itens já lançados | `{api}MesaI/{mesa}/{local}/{posicao}/{titulo}` |
| Enviar pedido | POST `{api}pedido` |
| Fechar conta | POST `{api}mesac` |

Fotos de produto: `{BaseImagens}produtos/{codigo}.{ExtProd}`. Ícone de grupo do app antigo não faz parte do contrato. No Flutter a categoria é texto.

### Campos usados

Parâmetros do tema, lista de `{parametro, valor}`: `BkColor_Pri`, `BkColor_Sec`, `Color_Bot`, `BackGround`, `ImgLogo`, `ImgFundo`, `ColorFontes_1`, `ColorFontes_2`, `ColorFontes_3`, `FontesGeral`, `parTaxaServico`, `HabilitaPosicao`, `NomePosicao`. Ausente: cor primária `#005495`, fundo branco, taxa 10, logo padrão se houver asset.

Setor: `descricaoSetor`.

Grupo: `codigoGrupo`, `descricaoGrupo`.

Produto: `codigo`, `descricao`, `preco`, `contemGluten`, `contemLactose`, `vegano`, `kcal`, `ingredientes`. Ignorar `imagemProduto` para a URL; a foto segue o padrão de arquivo acima. Se a imagem falhar, placeholder.

Observação: `obs_descricao`.

Cliente por título: `status` (`OK`), `status_socio` (`99` bloqueia), `texto` (nome). Texto contendo `Título não encontrado.` é erro de título.

Cliente por senha: corpo `Sem cadastro.` é senha inválida. JSON válido precisa de `codigo_cliente`. Guardar `id_socio`.

Status: `socio`, `fechaConta`, e `posicao` ou `mesa` conforme o endpoint. Corpo `Mesa não encontrada.` significa mesa livre para o título informado.

Cabeçalho da conta: `abertura`, `atendente`, `valorConsumido`, `socio`.

Item da conta, no JSON atual da API: `itm_produto`, `itm_descricao`, `itm_quantidade`, `itm_valor`. Se a resposta ainda trouxer `prd`, `desc`, `qtd` e `vlr`, aceitar como o mesmo dado.

### Respostas do POST pedido

Corpo vazio com HTTP 200: pedido enviado.

Corpo, depois de tirar aspas e quebras, começando com `OK|`: ler `POSICAO=` do segundo trecho separado por `|`, gravar a posição, pedido enviado.

JSON com `Message` igual a `Mesa se encontra fechada.`, `Mesa se encontra aberta em outro sócio.` ou `Socio já esta logado em outra mesa.`: mostrar a mensagem, esvaziar o carrinho, manter o título, voltar ao cardápio.

`Message` começando com `Mesa se encontra fechada.` ou com `Erro ao gravar pedido. Violação da restrição PRIMARY KEY 'PK_MESAH'`: tratar como mesa fechada.

Qualquer outro corpo: mostrar a mensagem da API sem o prefixo técnico `Error: Status`.

### Resposta do POST MesaC

HTTP 200 e corpo vazio: pagamento enviado. Outro corpo: mostrar o texto.
