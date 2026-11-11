import 'dart:convert';

import '../format/money.dart';
import '../../shared/models/json_values.dart';

const msgTituloVazio = 'Informe o título';
const msgSessaoExpirada = 'O acesso expirou. Leia o QR Code novamente.';
const msgMesaFechada = 'Mesa já fechada. Solicite o recebimento ao garçom.';
const msgDigiteSenha = 'Digite a senha';
const msgTituloNaoEncontrado = 'Título não encontrado';
const msgAcessoIndisponivel = 'Acesso indisponível para este título';
const msgSenhaInvalida = 'Senha inválida';
const msgParametrosNaoEncontrados = 'Parâmetros não encontrado.';
const msgLocalNaoEncontrado = 'Local não encontrado.';

enum PortaAcao { tituloVazio, seguir }

class PortaAcesso {
  final PortaAcao acao;
  final String mensagem;

  const PortaAcesso(this.acao, this.mensagem);

  static const seguir = PortaAcesso(PortaAcao.seguir, '');
}

PortaAcesso portaAcesso({required String titulo}) {
  if (titulo.trim().isEmpty) {
    return const PortaAcesso(PortaAcao.tituloVazio, msgTituloVazio);
  }
  return PortaAcesso.seguir;
}

bool sessaoExpirada({
  required DateTime agora,
  required DateTime horaEntrada,
  required int tempoExpira,
}) {
  return agora.difference(horaEntrada).inSeconds > tempoExpira;
}

bool modoPosicaoMesa(bool habilitaPosicao, String nomePosicao) {
  return habilitaPosicao && nomePosicao.trim().toUpperCase() == 'MESA';
}

class ClubeLido {
  final Map<String, String> parametros;
  final double taxa;
  final bool habilitaPosicao;
  final String nomePosicao;

  const ClubeLido({
    required this.parametros,
    required this.taxa,
    required this.habilitaPosicao,
    required this.nomePosicao,
  });
}

ClubeLido lerClube(Object? dados) {
  final parametros = mapaParametros(dados);
  final taxaBruta = parametros['parTaxaServico'];
  final taxa =
      (taxaBruta == null || taxaBruta.isEmpty) ? 10.0 : asDouble(taxaBruta);
  return ClubeLido(
    parametros: parametros,
    taxa: taxa,
    habilitaPosicao: parametros['HabilitaPosicao'] == '1',
    nomePosicao: parametros['NomePosicao'] ?? '',
  );
}

Map<String, String> mapaParametros(Object? dados) {
  if (dados is! List) return {};
  final mapa = <String, String>{};
  for (final item in dados) {
    final map = asMap(item);
    final chave = asString(map['parametro']).trim();
    if (chave.isEmpty) continue;
    mapa[chave] = asString(map['valor']).trim();
  }
  return mapa;
}

String lerDescricaoSetor(Object? dados) {
  if (dados is! Map) return '';
  return asString(asMap(dados)['descricaoSetor']).trim();
}

String? bloqueioCarga({
  required String corpoParametros,
  required String corpoSetor,
}) {
  final parametros = _comeca(corpoParametros, 'Parametros não encontrado') ||
      _comeca(corpoParametros, 'Parâmetros não encontrado');
  final local = _comeca(corpoSetor, 'Local não encontrado');
  if (parametros && local) {
    return '$msgParametrosNaoEncontrados $msgLocalNaoEncontrado';
  }
  if (parametros) return msgParametrosNaoEncontrados;
  if (local) return msgLocalNaoEncontrado;
  return null;
}

class StatusMesaLido {
  final bool invalido;
  final String mensagem;
  final String socio;
  final String fechaConta;
  final int posicao;
  final bool gravarPosicao;
  final String referenciaStatus;

  const StatusMesaLido({
    required this.invalido,
    required this.mensagem,
    required this.socio,
    required this.fechaConta,
    required this.posicao,
    required this.gravarPosicao,
    required this.referenciaStatus,
  });
}

StatusMesaLido interpretarStatus({
  required String corpo,
  required bool modoPosicao,
  required String titulo,
  required int posicaoAtual,
}) {
  if (_texto(corpo) == 'Mesa não encontrada.') {
    return StatusMesaLido(
      invalido: false,
      mensagem: '',
      socio: titulo,
      fechaConta: '0',
      posicao: posicaoAtual,
      gravarPosicao: false,
      referenciaStatus: '0',
    );
  }
  final map = _mapa(corpo);
  if (map == null) {
    final texto = _texto(corpo);
    return StatusMesaLido(
      invalido: true,
      mensagem: texto,
      socio: '',
      fechaConta: '0',
      posicao: posicaoAtual,
      gravarPosicao: false,
      referenciaStatus: '0',
    );
  }
  final temPosicao = map.containsKey('posicao') && map['posicao'] != null;
  return StatusMesaLido(
    invalido: false,
    mensagem: '',
    socio: asString(map['socio']).trim(),
    fechaConta: fechaContaTexto(map['fechaConta']),
    posicao: temPosicao ? asInt(map['posicao']) : posicaoAtual,
    gravarPosicao: temPosicao,
    referenciaStatus:
        modoPosicao ? _referencia(map['mesa']) : _referencia(map['posicao']),
  );
}

String fechaContaTexto(dynamic value) {
  if (value == null) return '0';
  if (value is bool) return value ? '1' : '0';
  if (value is num) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }
  final text = value.toString().trim();
  return text.isEmpty ? '0' : text;
}

enum TravaMesa { seguir, fechada, anterior }

TravaMesa classificarMesa({
  required String fechaConta,
  required String referenciaStatus,
  required int mesaQr,
}) {
  if (fechaConta != '0' && _igualMesa(referenciaStatus, mesaQr)) {
    return TravaMesa.fechada;
  }
  if (referenciaStatus != '0' &&
      !_igualMesa(referenciaStatus, mesaQr) &&
      fechaConta == '0') {
    return TravaMesa.anterior;
  }
  return TravaMesa.seguir;
}

enum AcaoMesaAnterior { seguir, outroSocio, pagar, texto }

class MesaAnteriorDecisao {
  final AcaoMesaAnterior acao;
  final String mensagem;
  final double total;

  const MesaAnteriorDecisao._(this.acao, this.mensagem, this.total);

  const MesaAnteriorDecisao.seguir() : this._(AcaoMesaAnterior.seguir, '', 0);

  const MesaAnteriorDecisao.outro(String mensagem, double total)
      : this._(AcaoMesaAnterior.outroSocio, mensagem, total);

  const MesaAnteriorDecisao.pagar(String mensagem, double total)
      : this._(AcaoMesaAnterior.pagar, mensagem, total);

  const MesaAnteriorDecisao.texto(String mensagem)
      : this._(AcaoMesaAnterior.texto, mensagem, 0);
}

MesaAnteriorDecisao decidirMesaAnterior({
  required String corpo,
  required String titulo,
  required int mesa,
  required int posicao,
  required String referenciaStatus,
  required double taxa,
}) {
  if (_texto(corpo) == 'Mesa não encontrada.') {
    return const MesaAnteriorDecisao.seguir();
  }
  final map = _mapa(corpo);
  if (map == null) {
    return MesaAnteriorDecisao.texto(_texto(corpo));
  }
  final total = totalComTaxa(asDouble(map['valorConsumido']), taxa);
  final socio = asString(map['socio']).trim();
  final reais = reaisNaTela(total);
  if (titulo.trim() != socio) {
    return MesaAnteriorDecisao.outro(
      'A mesa $mesa posição $posicao está aberta para o sócio $socio, '
      'no valor de $reais. Solicite o apoio do atendente.',
      total,
    );
  }
  return MesaAnteriorDecisao.pagar(
    'A mesa $referenciaStatus está aberta para o sócio ${titulo.trim()}, '
    'no valor de $reais. Deseja pagar a mesa acima?',
    total,
  );
}

double totalComTaxa(double valorConsumido, double taxa) {
  return valorConsumido + valorConsumido * taxa / 100;
}

String reaisNaTela(num value) => formatMoney(value).replaceAll('\u00A0', ' ');

enum ClienteTrava { ok, naoEncontrado, indisponivel }

class ClienteDecisao {
  final ClienteTrava trava;
  final String nome;
  final int idSocio;
  final String mensagem;

  const ClienteDecisao._(this.trava, this.nome, this.idSocio, this.mensagem);

  const ClienteDecisao.ok(String nome, int idSocio)
      : this._(ClienteTrava.ok, nome, idSocio, '');

  const ClienteDecisao.naoEncontrado()
      : this._(ClienteTrava.naoEncontrado, '', 0, msgTituloNaoEncontrado);

  const ClienteDecisao.indisponivel()
      : this._(ClienteTrava.indisponivel, '', 0, msgAcessoIndisponivel);
}

ClienteDecisao decidirCliente(String corpo) {
  if (_contem(corpo, 'Título não encontrado.')) {
    return const ClienteDecisao.naoEncontrado();
  }
  final map = _mapa(corpo);
  if (map == null) return const ClienteDecisao.naoEncontrado();
  if (asString(map['status_socio']).trim() == '99') {
    return const ClienteDecisao.indisponivel();
  }
  if (asString(map['status']).trim() == 'OK') {
    final id = map.containsKey('id_socio') && map['id_socio'] != null
        ? asInt(map['id_socio'])
        : 0;
    return ClienteDecisao.ok(asString(map['texto']).trim(), id);
  }
  return const ClienteDecisao.naoEncontrado();
}

enum PassoSenha { semSenha, pedirSenha, comSenha }

PassoSenha passoSenha({required String senha, required String semSenha}) {
  if (senha.isEmpty && semSenha == '1') return PassoSenha.semSenha;
  if (senha.isEmpty) return PassoSenha.pedirSenha;
  return PassoSenha.comSenha;
}

enum AcaoSenha { invalida, texto, entrar }

class SenhaDecisao {
  final AcaoSenha acao;
  final int idSocio;
  final String mensagem;

  const SenhaDecisao._(this.acao, this.idSocio, this.mensagem);

  const SenhaDecisao.invalida()
      : this._(AcaoSenha.invalida, 0, msgSenhaInvalida);

  const SenhaDecisao.texto(String mensagem)
      : this._(AcaoSenha.texto, 0, mensagem);

  const SenhaDecisao.entrar(int idSocio)
      : this._(AcaoSenha.entrar, idSocio, '');
}

SenhaDecisao decidirSenha(String corpo) {
  if (_texto(corpo) == 'Sem cadastro.') return const SenhaDecisao.invalida();
  final map = _mapa(corpo);
  if (map == null ||
      !map.containsKey('codigo_cliente') ||
      map['codigo_cliente'] == null) {
    return SenhaDecisao.texto(_texto(corpo));
  }
  final id = map.containsKey('id_socio') && map['id_socio'] != null
      ? asInt(map['id_socio'])
      : 0;
  return SenhaDecisao.entrar(id);
}

String _texto(String corpo) {
  final trim = corpo.trim();
  if (trim.isEmpty) return '';
  try {
    final decoded = jsonDecode(trim);
    if (decoded is String) return decoded.trim();
  } catch (_) {}
  return trim;
}

Map<String, dynamic>? _mapa(String corpo) {
  final trim = corpo.trim();
  if (trim.isEmpty) return null;
  try {
    final decoded = jsonDecode(trim);
    if (decoded is Map) return asMap(decoded);
  } catch (_) {}
  return null;
}

bool _contem(String corpo, String frase) {
  return _texto(corpo).contains(frase) || corpo.contains(frase);
}

bool _comeca(String corpo, String frase) {
  final texto = _texto(corpo);
  return texto.startsWith(frase) || corpo.trim().startsWith(frase);
}

String _referencia(dynamic value) {
  if (value == null) return '0';
  if (value is num) return value.toInt().toString();
  final text = value.toString().trim();
  return text.isEmpty ? '0' : text;
}

bool _igualMesa(String referencia, int mesa) {
  final numero = int.tryParse(referencia.trim());
  if (numero != null) return numero == mesa;
  return referencia.trim() == mesa.toString();
}
