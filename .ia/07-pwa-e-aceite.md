# Parte 7 — PWA, sessão e aceite

Cole esta mensagem inteira num chat novo. O workspace é `cardapio_solarium_flutter`.

Não altere o NSBasic nem a ApiCardapio. Esta parte não muda regra de mesa, formato de POST nem endpoint. Ela fecha o que um sócio percebe no celular e confere o conjunto. O PWA continua chamando a ApiCardapio direto.

## PWA

`flutter build web` gera um PWA instalável.

- Nome: Solarium Cardápio
- `display`: standalone
- `start_url` relativa, para o QR `index.html?70&2` continuar válido na pasta HTTPS publicada por FTP em `ftp.sicomtec.com.br`
- `theme_color` e `background_color`: `#005495` até o clube carregar; depois que o tema chegar, não é obrigatório atualizar o manifest
- Ícones 192 e 512. Se não houver arte nova, usar um ícone simples com as iniciais, sem copiar arte de terceiros
- Não apontar `scope` para a pasta do NSBasic

O serviço worker padrão do Flutter pode cachear o app. A API e as fotos não entram em cache agressivo: cardápio e conta precisam refletir o que a cozinha gravou. Configurar o cache do Flutter web para não servir GET de pedido, mesa ou produto como conteúdo velho de horas.

## Sessão

`TempoExpira` conta da hora de entrada gravada na abertura do QR, não do último toque.

Checar de novo ao abrir cardápio, conta e pagamento, além dos pontos que as partes 2 e 5 já checam. Expirado: diálogo “O acesso expirou. Leia o QR Code novamente.” e volta à entrada. Carrinho local pode permanecer na preferência, mas a tela não deixa enviar.

Refresh no meio do cardápio, com título já gravado e mesa ainda na URL, reabre logado se a sessão não expirou: não pedir senha outra vez. Sem título gravado, mostrar o login. Sem query, não inventar a mesa que estava na visita anterior.

Senha nunca vai para `shared_preferences`, log ou query string.

## Visual de fechamento

Percorrer as telas e ajustar só o que fugir do padrão já especificado:

- coluna de 480 px no desktop, largura toda no celular
- área segura no topo e na barra flutuante
- um só cabeçalho compacto
- botões primários na cor do clube
- texto de glúten com acento
- snackbar de sucesso, diálogo só para confirmação e bloqueio
- loading no botão que dispara rede, sem segundo toque

Não redesenhar fluxo nem acrescentar busca por voz, cupom, gorjeta editável, delivery ou WhatsApp.

## Aceite

Rodar `flutter analyze` e `flutter test`. Corrigir o que estes comandos apontarem nos arquivos do projeto.

Conferir, em dispositivo estreito ou no Chrome com viewport de 390×844, este roteiro. Onde não houver mesa de teste, o teste de unidade correspondente precisa existir.

1. Sem query: pede o QR e não mostra título.
2. `?mesa&local`: mostra mesa, local, nome do setor e cor primária da API.
3. Título vazio, título inexistente e senha inválida usam as frases da parte 2.
4. Acesso válido cai no cardápio, não numa lista só de grupos.
5. Chip, scroll e busca sem acento funcionam.
6. “+” soma 1 sem observação e a barra aparece.
7. O card abre o sheet; 5 observações entram; a sexta não entra; texto livre corta em 50.
8. Mesmo produto com as mesmas observações funde a linha.
9. Carrinho altera quantidade, remove com confirmação, limpa com confirmação.
10. Enviar com carrinho vazio é impossível. O corpo montado no teste tem `Hdm_Local` = posição, `itm_mesa`, `itm_posicao`, 9999 nos PDVs, `CELULAR`, e `itm_observacao1`…`itm_observacao5`. A URL é `{IpApiCardapio}pedido`.
11. Resposta `OK|POSICAO=n` atualiza a posição do cabeçalho e esvazia o carrinho.
12. Conta só leitura. Pagamento mostra taxa e total. O JSON de teste tem `rec_codsat` `"0"` e `mcl_Posicao`, no `POST mesac`.
13. Mesa fechada não paga.
14. Sessão expirada não envia pedido nem pagamento e não abre outro site.

Entregar um resumo curto: o que foi verificado no browser, o que ficou só em teste de unidade, e qualquer diferença consciente em relação ao NSBasic (chamada direta à API com `Hdm_*` e `itm_*`, fotos em `BaseImagens`, chips em vez de tela de grupos, taxa não editável, terceiro parâmetro da URL ignorado, mesa anterior paga com a mesa do QR).

Não publicar por cima do cardápio NSBasic. O `flutter build web` sobe por FTP em `ftp.sicomtec.com.br`, numa pasta própria do PWA, servida em HTTPS. As fotos de produto ficam em `{pasta do PWA}/imagens/produtos/`.
