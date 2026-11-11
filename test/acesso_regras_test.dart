import 'package:cardapio_solarium/core/acesso/acesso_regras.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mesa = 70;
  const titulo = '12345';

  group('mesa livre', () {
    test('corpo de mesa não encontrada segue sem mudar a posição', () {
      final status = interpretarStatus(
        corpo: 'Mesa não encontrada.',
        modoPosicao: false,
        titulo: titulo,
        posicaoAtual: 1,
      );
      expect(status.socio, titulo);
      expect(status.fechaConta, '0');
      expect(status.gravarPosicao, isFalse);
      expect(status.posicao, 1);
      expect(status.referenciaStatus, '0');
      expect(
        classificarMesa(
          fechaConta: status.fechaConta,
          referenciaStatus: status.referenciaStatus,
          mesaQr: mesa,
        ),
        TravaMesa.seguir,
      );
    });

    test('no modo posição também não inventa posição', () {
      final status = interpretarStatus(
        corpo: '"Mesa não encontrada."',
        modoPosicao: true,
        titulo: titulo,
        posicaoAtual: 0,
      );
      expect(status.gravarPosicao, isFalse);
      expect(status.posicao, 0);
      expect(status.referenciaStatus, '0');
    });
  });

  group('mesa fechada', () {
    test('fechaConta diferente de 0 e referência igual à mesa do QR', () {
      final status = interpretarStatus(
        corpo: '{"socio":"12345","fechaConta":"1","posicao":70}',
        modoPosicao: false,
        titulo: titulo,
        posicaoAtual: 1,
      );
      expect(status.referenciaStatus, '70');
      expect(status.gravarPosicao, isTrue);
      expect(status.posicao, 70);
      expect(
        classificarMesa(
          fechaConta: status.fechaConta,
          referenciaStatus: status.referenciaStatus,
          mesaQr: mesa,
        ),
        TravaMesa.fechada,
      );
    });

    test('no modo posição a referência é a mesa do JSON', () {
      final status = interpretarStatus(
        corpo: '{"socio":"12345","fechaConta":"2","mesa":70,"posicao":3}',
        modoPosicao: true,
        titulo: titulo,
        posicaoAtual: 0,
      );
      expect(status.referenciaStatus, '70');
      expect(status.posicao, 3);
      expect(
        classificarMesa(
          fechaConta: status.fechaConta,
          referenciaStatus: status.referenciaStatus,
          mesaQr: mesa,
        ),
        TravaMesa.fechada,
      );
    });

    test(
        'fechaConta fechado em outra referência não bloqueia como mesa fechada',
        () {
      expect(
        classificarMesa(fechaConta: '1', referenciaStatus: '12', mesaQr: mesa),
        TravaMesa.seguir,
      );
    });
  });

  group('mesa anterior', () {
    const corpoStatus = '{"socio":"12345","fechaConta":"0","posicao":12}';

    StatusMesaLido statusAberto() {
      return interpretarStatus(
        corpo: corpoStatus,
        modoPosicao: false,
        titulo: titulo,
        posicaoAtual: 1,
      );
    }

    test('posição diferente da mesa do QR pede o cabeçalho', () {
      final status = statusAberto();
      expect(status.referenciaStatus, '12');
      expect(status.posicao, 12);
      expect(
        classificarMesa(
          fechaConta: status.fechaConta,
          referenciaStatus: status.referenciaStatus,
          mesaQr: mesa,
        ),
        TravaMesa.anterior,
      );
    });

    test('mesmo título pergunta se deseja pagar e cita a referência', () {
      final decisao = decidirMesaAnterior(
        corpo: '{"valorConsumido":48,"socio":"12345"}',
        titulo: titulo,
        mesa: mesa,
        posicao: 12,
        referenciaStatus: '12',
        taxa: 10,
      );
      expect(decisao.acao, AcaoMesaAnterior.pagar);
      expect(decisao.total, 52.8);
      expect(
        decisao.mensagem,
        'A mesa 12 está aberta para o sócio 12345, '
        'no valor de R\$ 52,80. Deseja pagar a mesa acima?',
      );
    });

    test('outro sócio pede apoio e usa a mesa e a posição do QR', () {
      final decisao = decidirMesaAnterior(
        corpo: '{"valorConsumido":10,"socio":"999"}',
        titulo: titulo,
        mesa: mesa,
        posicao: 12,
        referenciaStatus: '12',
        taxa: 10,
      );
      expect(decisao.acao, AcaoMesaAnterior.outroSocio);
      expect(decisao.total, 11);
      expect(
        decisao.mensagem,
        'A mesa 70 posição 12 está aberta para o sócio 999, '
        'no valor de R\$ 11,00. Solicite o apoio do atendente.',
      );
    });

    test('cabeçalho de mesa não encontrada segue o login sem diálogo', () {
      final decisao = decidirMesaAnterior(
        corpo: 'Mesa não encontrada.',
        titulo: titulo,
        mesa: mesa,
        posicao: 12,
        referenciaStatus: '12',
        taxa: 10,
      );
      expect(decisao.acao, AcaoMesaAnterior.seguir);
    });
  });

  group('sem senha', () {
    test('senha vazia com SemSenha 1 entra pelo título', () {
      expect(
        passoSenha(senha: '', semSenha: '1'),
        PassoSenha.semSenha,
      );
      final cliente = decidirCliente(
        '{"status":"OK","texto":"Ana Souza"}',
      );
      expect(cliente.trava, ClienteTrava.ok);
      expect(cliente.nome, 'Ana Souza');
      expect(cliente.idSocio, 0);
    });

    test('guarda id_socio quando o título traz o campo', () {
      final cliente = decidirCliente(
        '{"status":"OK","texto":"Ana","id_socio":"15"}',
      );
      expect(cliente.idSocio, 15);
    });

    test('senha vazia sem a flag pede a senha', () {
      expect(passoSenha(senha: '', semSenha: '0'), PassoSenha.pedirSenha);
    });

    test('status_socio 99 bloqueia', () {
      final cliente = decidirCliente(
        '{"status":"OK","status_socio":"99","texto":"Ana"}',
      );
      expect(cliente.trava, ClienteTrava.indisponivel);
      expect(cliente.mensagem, 'Acesso indisponível para este título');
    });

    test('título inexistente limpa a mensagem combinada', () {
      expect(
        decidirCliente('"Título não encontrado."').trava,
        ClienteTrava.naoEncontrado,
      );
      expect(
        decidirCliente('Título não encontrado.').mensagem,
        'Título não encontrado',
      );
    });

    test('senha inválida e senha aceita', () {
      expect(passoSenha(senha: 'abc', semSenha: '0'), PassoSenha.comSenha);
      expect(decidirSenha('Sem cadastro.').acao, AcaoSenha.invalida);
      expect(decidirSenha('"Sem cadastro."').mensagem, 'Senha inválida');

      final semId = decidirSenha('{"codigo_cliente":1}');
      expect(semId.acao, AcaoSenha.entrar);
      expect(semId.idSocio, 0);

      final comId = decidirSenha('{"codigo_cliente":1,"id_socio":9}');
      expect(comId.acao, AcaoSenha.entrar);
      expect(comId.idSocio, 9);

      expect(
        decidirSenha('{"texto":"falhou"}').mensagem,
        '{"texto":"falhou"}',
      );
    });
  });

  group('porta de acesso', () {
    test('título vazio para antes da rede', () {
      final porta = portaAcesso(titulo: '  ');
      expect(porta.acao, PortaAcao.tituloVazio);
      expect(porta.mensagem, 'Informe o título');
    });

    test('a senha segue mesmo com a entrada vencida', () {
      final entrada = DateTime(2026, 11, 9, 18);
      expect(portaAcesso(titulo: titulo).acao, PortaAcao.seguir);
      expect(
        sessaoExpirada(
          agora: entrada.add(const Duration(seconds: 14400)),
          horaEntrada: entrada,
          tempoExpira: 14400,
        ),
        isFalse,
      );
      expect(
        sessaoExpirada(
          agora: entrada.add(const Duration(seconds: 14401)),
          horaEntrada: entrada,
          tempoExpira: 14400,
        ),
        isTrue,
      );
    });
  });

  test('parâmetros e bloqueio de carga', () {
    final clube = lerClube(const [
      {'parametro': 'parTaxaServico', 'valor': '12'},
      {'parametro': 'HabilitaPosicao', 'valor': '1'},
      {'parametro': 'NomePosicao', 'valor': 'mesa'},
    ]);
    expect(clube.taxa, 12);
    expect(modoPosicaoMesa(clube.habilitaPosicao, clube.nomePosicao), isTrue);
    expect(lerClube(const []).taxa, 10);
    expect(
      bloqueioCarga(
        corpoParametros: '"Parametros não encontrado."',
        corpoSetor: '{"descricaoSetor":"Restaurante"}',
      ),
      'Parâmetros não encontrado.',
    );
    expect(
      bloqueioCarga(
        corpoParametros: '[]',
        corpoSetor: 'Local não encontrado.',
      ),
      'Local não encontrado.',
    );
    expect(lerDescricaoSetor({'descricaoSetor': 'Restaurante'}), 'Restaurante');
  });
}
