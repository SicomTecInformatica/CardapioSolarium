# Parte 2 — Tema, sessão e login do sócio

Cole esta mensagem inteira num chat novo. O workspace é `cardapio_solarium_flutter`, criado na parte 1.

Leia `prompts-flutter/00-como-usar.md` se estiver acessível. O contrato abaixo é o que esta parte usa. Não altere o NSBasic nem a ApiCardapio. As chamadas saem direto de `IpApiCardapio`, sem PHP. Não implemente cardápio, produto, carrinho nem conta; a rota depois do login pode ser um placeholder “Cardápio”.

## Objetivo

Abrir pelo QR, pintar o app com as cores do clube e entrar com título e senha, com as mesmas travas de mesa do app atual.

## Fluxo

1. App lê `?mesa&local` (já feito na parte 1). Sem mesa ou sem local, ficar na entrada e pedir para ler o QR. Sem botão que invente mesa.
2. Buscar `setor/setorparametros/{local}` e `setor/{local}`.
3. Aplicar o tema e mostrar a tela de acesso.
4. Ao tocar em Acessar, rodar as regras abaixo.
5. Sucesso: gravar título, nome e `id_socio`, ir para o placeholder do cardápio.

Enquanto os parâmetros carregam, skeleton no lugar do formulário. Falha de rede: “Sem conexão. Tente de novo.” e botão Repetir. Corpo `Parametros não encontrado` ou `Local não encontrado.`: diálogo com esse sentido, formulário desabilitado.

## Tema

Lista `{parametro, valor}`:

| parametro | Uso |
|---|---|
| `BkColor_Pri` | cor primária, botões, chips selecionados |
| `BkColor_Sec` | superfície |
| `Color_Bot` | texto de botão se vier; senão branco |
| `BackGround` | gradiente do login, pelo parser da parte 1 |
| `ImgLogo` | logo; se for caminho relativo, prefixar `BaseImagens` (ou a origem do site, se a URL não for `http`) |
| `ImgFundo` | fundo do login, `BoxFit.cover`; caminho relativo usa a mesma regra da logo |
| `FontesGeral` | `fontFamily`, fallback Roboto |
| `parTaxaServico` | número da taxa, padrão 10; guardar na sessão |
| `HabilitaPosicao` | `"1"` liga o modo posição |
| `NomePosicao` | se for `MESA` (sem diferenciar maiúsculas), posição inicial 0 e o status usa o outro endpoint |

Logo quebrada: seguir sem imagem. Não bloquear o acesso.

## Tela de acesso (padrão Goomer de abertura)

Fundo do clube, conteúdo em coluna central.

- Logo até 120 px de largura.
- Nome do setor.
- “Mesa {n}” e, se a posição for diferente de 0, “Posição {n}”.
- Campo Título, teclado numérico se couber, texto já digitado recuperado da preferência.
- Campo Senha, oculto. Se `SemSenha` for `"1"`, o campo continua visível, mas vazio é aceito pela regra abaixo.
- Botão largo “Acessar”, 48 px de altura, cor primária.
- Erro do campo fica sob o campo, não só em diálogo. Diálogo fica para as travas de mesa.

Nada de versão, botão de limpar storage nem cabeçalho repetido de 4 linhas.

## Regras do Acessar, nesta ordem

Título vazio: “Informe o título”. Parar.

Sessão: se `agora - horaDeEntrada` for maior que `TempoExpira` segundos, diálogo “O acesso expirou. Leia o QR Code novamente.” Não redirecionar para site de homologação. Não zerar a mesa lida do QR.

Gravar o título na preferência antes das chamadas, como o app atual.

Escolher o status:

- Se `HabilitaPosicao == "1"` e `NomePosicao` é `MESA`: `MesaH/lermesahstatusposicao/{mesa}/{local}/{titulo}`.
- Senão: `MesaH/lermesahstatus/{mesa}/{local}/{posicao}/{titulo}`.

Corpo `Mesa não encontrada.`: mesa livre. Tratar `socio` como o título digitado, `fechaConta` como `"0"`. No endpoint normal, não mudar a posição. No endpoint de posição, não inventar posição.

JSON de status:

- Endpoint normal: `socio`, `fechaConta`, `posicao`. Guardar `posicao` na sessão (passa a ser a posição corrente) e também numa variável `referenciaStatus` usada só nas comparações abaixo. No app atual essa variável se chama `axStatusMesa`, mas o valor copiado é `posicao`.
- Endpoint de posição: `socio`, `fechaConta`, `mesa`, `posicao`. Guardar `posicao` na sessão. `referenciaStatus` recebe `mesa`.

`fechaConta` diferente de `"0"` e `referenciaStatus` igual à mesa do QR: “Mesa já fechada. Solicite o recebimento ao garçom.” Parar.

O terceiro parâmetro da URL continua ignorado, então a trava “posição lida na URL e sócio diferente” não roda. Não implementá-la.

Se `referenciaStatus` não é `"0"`, é diferente da mesa do QR e `fechaConta` é `"0"`: a mesa anterior está aberta. Buscar `MesaH/{mesaDoQr}/{local}/{posicao}/{titulo}`. Se o corpo for mesa não encontrada, seguir o login sem diálogo. Se vier JSON, calcular total = `valorConsumido` + `valorConsumido` × taxa/100.

- Se o título digitado for diferente de `socio` desse cabeçalho: “A mesa {mesa} posição {posicao} está aberta para o sócio {socio}, no valor de R$ {total}. Solicite o apoio do atendente.” Parar.
- Se for o mesmo título: diálogo “A mesa {referenciaStatus} está aberta para o sócio {titulo}, no valor de R$ {total}. Deseja pagar a mesa acima?” Sim / Não. Não segue para o cardápio neste toque. Sim executa o pagamento da parte 6 se ele já existir; se a parte 6 ainda não existe, deixar um método `pagarMesaAtual(valor)` com `TODO` claro e o diálogo já funcionando até o Sim, que por enquanto mostra “Pagamento entra na etapa da conta”. Não pagar mesa diferente da do QR: o código atual chama o pagamento com a mesa e a posição do QR, e a mensagem é que cita `referenciaStatus`.

Senha:

- Senha vazia e `SemSenha == "1"`: `GET Cliente/{titulo}`. Corpo com `Título não encontrado.`: “Título não encontrado”, limpar os campos. `status_socio == "99"`: “Acesso indisponível para este título”. `status == "OK"`: guardar `texto` como nome, `id_socio` fica 0 se não vier, entrar. Senão: “Título não encontrado”.
- Senha vazia e `SemSenha != "1"`: “Digite a senha”.
- Senha preenchida: `GET Cliente/{titulo}` com as mesmas travas de título e de `99`. Depois `GET Cliente/{titulo}/{senha}`. Corpo `Sem cadastro.`: “Senha inválida”, limpar só a senha. JSON sem `codigo_cliente`: mostrar o texto recebido. JSON com `codigo_cliente`: guardar `id_socio` (0 se ausente) e entrar.

Não pedir token. O token antigo está desligado.

## Placeholder depois do login

Rota `/cardapio`. AppBar curta: logo 28 px, nome do setor, “Mesa n” e posição se não for 0. Corpo: “Cardápio na próxima etapa”. Sair volta ao login e não apaga o título gravado. Não apagar o carrinho aqui.

## Pronto quando

- Com `?70&2` (ou outra mesa de teste que você tenha), a tela mostra setor, mesa e cores vindas da API.
- Título vazio, título inexistente, senha errada e `status_socio` 99 mostram as frases acima.
- Mesa com `fechaConta` diferente de `"0"` no caso em que `referenciaStatus` coincide com a mesa bloqueia com o texto do garçom.
- Sem query, não há como acessar.
- `flutter analyze` sem erros novos. Testes de unidade das decisões puras (mesa livre, mesa fechada, mesa anterior, sem senha), com JSON fixo, sem rede.
