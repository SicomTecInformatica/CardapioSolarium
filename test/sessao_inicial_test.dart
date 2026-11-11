import 'package:cardapio_solarium/core/session/qr_mesa.dart';
import 'package:cardapio_solarium/core/session/sessao_inicial.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final agora = DateTime(2026, 11, 10, 12);
  final entrada = DateTime(2026, 11, 10, 8);

  test('sem query não inventa a mesa da visita anterior', () {
    final sessao = decidirSessaoInicial(
      qr: parseQrMesa('https://cardapio.exemplo/index.html'),
      agora: agora,
      tempoExpira: 14400,
      titulo: '12345',
      nomeSocio: 'Ana',
      idSocio: 9,
      mesaGravada: 70,
      localGravado: 2,
      horaGravada: entrada,
    );
    expect(sessao.mesa, 0);
    expect(sessao.local, 0);
    expect(sessao.temQuery, isFalse);
    expect(sessao.autenticado, isFalse);
    expect(sessao.gravarEntrada, isFalse);
  });

  test('título gravado na mesma mesa pede a senha e mantém a hora original', () {
    final sessao = decidirSessaoInicial(
      qr: parseQrMesa('https://cardapio.exemplo/pwa/index.html?70&2'),
      agora: agora,
      tempoExpira: 14400,
      titulo: '12345',
      nomeSocio: 'Ana',
      idSocio: 9,
      mesaGravada: 70,
      localGravado: 2,
      horaGravada: entrada,
    );
    expect(sessao.autenticado, isFalse);
    expect(sessao.horaEntrada, entrada);
    expect(sessao.gravarEntrada, isFalse);
    expect(sessao.nomeSocio, isEmpty);
    expect(sessao.idSocio, 0);
    expect(sessao.mesa, 70);
    expect(sessao.local, 2);
  });

  test('sem título gravado fica no login', () {
    final sessao = decidirSessaoInicial(
      qr: parseQrMesa('https://cardapio.exemplo/index.html?70&2'),
      agora: agora,
      tempoExpira: 14400,
      titulo: '  ',
      mesaGravada: 70,
      localGravado: 2,
      horaGravada: entrada,
    );
    expect(sessao.autenticado, isFalse);
    expect(sessao.mesa, 70);
    expect(sessao.local, 2);
  });

  test('sessão vencida não entra e não empurra a hora do QR', () {
    final sessao = decidirSessaoInicial(
      qr: parseQrMesa('https://cardapio.exemplo/index.html?70&2&9'),
      agora: entrada.add(const Duration(seconds: 14401)),
      tempoExpira: 14400,
      titulo: '12345',
      nomeSocio: 'Ana',
      idSocio: 9,
      mesaGravada: 70,
      localGravado: 2,
      horaGravada: entrada,
    );
    expect(sessao.autenticado, isFalse);
    expect(sessao.horaEntrada, entrada);
    expect(sessao.gravarEntrada, isFalse);
    expect(sessao.nomeSocio, isEmpty);
    expect(sessao.mesa, 70);
  });

  test('outro QR grava uma entrada nova', () {
    final sessao = decidirSessaoInicial(
      qr: parseQrMesa('https://cardapio.exemplo/index.html?12&3'),
      agora: agora,
      tempoExpira: 14400,
      titulo: '12345',
      nomeSocio: 'Ana',
      idSocio: 9,
      mesaGravada: 70,
      localGravado: 2,
      horaGravada: entrada,
    );
    expect(sessao.gravarEntrada, isTrue);
    expect(sessao.horaEntrada, agora);
    expect(sessao.autenticado, isFalse);
    expect(sessao.mesa, 12);
    expect(sessao.local, 3);
  });
}
