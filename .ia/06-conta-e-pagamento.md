# Parte 6 — Conta e pagamento

Cole esta mensagem inteira num chat novo. O workspace é `cardapio_solarium_flutter`.

Não altere o NSBasic nem a ApiCardapio. Não exponha campo para o sócio digitar a taxa. A taxa é `parTaxaServico`, já guardada na sessão. O atalho de taxa livre do app antigo fica de fora. Conta e pagamento usam `GET` e `POST` direto em `IpApiCardapio`.

## Objetivo

Duas telas no lugar de Consulta e Pagamento juntas: o que já foi lançado na mesa, e o fechamento. O ícone de conta no cardápio deixa o placeholder e abre esta conta. O pagamento da mesa anterior, deixado em aberto na parte 2, passa a funcionar de verdade.

## Conta

Rota `/conta`.

Ao abrir, `GET MesaI/{mesa}/{local}/{posicao}/{titulo}`.

- Corpo `[]` ou mesa não encontrada: “Nenhum item lançado nesta mesa.” e voltar disponível. Sem diálogo bloqueando o cardápio.
- Lista: foto, nome, quantidade, valor da linha. Ler `itm_descricao`, `itm_quantidade` e `itm_valor`. Se a resposta trouxer `desc`, `qtd` e `vlr`, usar esses. A foto usa `itm_produto` ou `prd`. Somar quantidade e valor para o rodapé “{n} itens · R$ {soma}”.
- Itens são somente leitura. Sem “+” e “−”.

Também `GET` do status (`lermesahstatus` ou `lermesahstatusposicao`, a mesma escolha da parte 2). Se `fechaConta` for diferente de `"0"` e a referência coincidir com a mesa, faixa “Mesa fechada. Solicite o recebimento ao garçom.” e o botão de pagar desabilitado.

Botão “Ir para pagamento”.

## Pagamento

Rota `/conta/pagamento`.

`GET MesaH/{mesa}/{local}/{posicao}/{titulo}`.

Mostrar, nesta ordem, rótulo à esquerda e valor à direita:

- Mesa
- Abertura: data e hora como o texto vier em `abertura`, sem reconstruir o relógio no cliente se o parse for ambíguo. Se `abertura` vier `dd/MM/yyyy HH:mm:ss`, mostrar `dd/MM/yyyy` e `HH:mm`.
- Atendente (`atendente`)
- Título e nome do sócio já guardados na sessão
- Total consumido: `valorConsumido`
- Taxa de serviço: “Taxa de serviço ({taxa}%)” e o valor `valorConsumido × taxa/100`
- Total: consumido + taxa

Botão “Pagar · R$ {total}”.

Se `SemSenha` não for `"1"`, o toque revela o campo Senha e o botão passa a “Confirmar pagamento”. Senha vazia: “Digite a senha”. Se `SemSenha` for `"1"`, confirmar direto.

Confirmação: “Enviar o pagamento de R$ {total}?” Sim / Não.

## POST MesaC

Checar `TempoExpira` antes. Expirado: não envia.

Se há senha, repetir `GET Cliente/{titulo}/{senha}`. `Sem cadastro.`: “Senha inválida”. Sem `codigo_cliente`: mostrar o texto. Sucesso: atualizar `id_socio`.

Antes do POST, reler o status. Erro de rede: “Não foi possível ler a mesa.” `fechaConta` diferente de `"0"`: “Mesa já fechada. Solicite o recebimento ao garçom.”

`POST mesac` com o objeto na raiz, nomes do `MesacModel.toMap()` do Sicom Comanda:

- `mcl_setor`: local, número
- `mcl_nummesa`: mesa, número
- `mcl_Cliente`: título numérico
- `mcl_NomeCliente`: nome do sócio
- `mcl_IdSocio`: id, número; 0 se desconhecido
- `mcl_Valor`: total com taxa, número JSON com duas casas
- `mcl_CancServico`: 0
- `mcl_NumFecConta`: 0
- `mcl_vrtxservico`: 0
- `rec_codsat`: `"0"`
- `mcl_Posicao`: posição, número

Sem wrapper `MesaC` em volta do objeto e sem PHP.

HTTP 200 e corpo vazio: snackbar “Pagamento enviado”. Limpar carrinho e campos voláteis, manter o título na preferência, voltar ao login.

HTTP 200 e corpo preenchido: diálogo com esse texto, permanecer na tela.

Rede: “Não foi possível enviar o pagamento.”, permanecer.

## Mesa anterior (parte 2)

O Sim do diálogo “Deseja pagar a mesa acima?” chama este mesmo pagamento, com a mesa e a posição do QR e o total já calculado (consumido + taxa). Não trocar para a mesa citada só na mensagem. Senha: se o sócio acabou de digitar no login, usar essa senha nesta confirmação; não pedir de novo se ela já foi validada neste toque. Se `SemSenha` não for `"1"` e a senha ainda não tiver sido conferida, conferir antes do POST.

## Pronto quando

- Conta lista os itens da API e o total da lista.
- Pagamento mostra consumido, taxa e total coerentes com `parTaxaServico`.
- Teste puro monta o JSON com `mcl_Posicao` e `rec_codsat` certos, e o total 100 com taxa 10 vira `110.00` numérico, não `11000`. A URL do POST é `{IpApiCardapio}mesac`.
- Mesa fechada não habilita pagar.
- O ícone do cardápio abre a conta. O carrinho e o envio de pedido continuam iguais.
