import 'package:cardapio_solarium/core/config/app_config.dart';
import 'package:cardapio_solarium/core/theme/club_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final pagina = Uri.parse('https://cardapio.exemplo/index.html?70&2');

  test('aplica cores, fonte e caminhos de imagem do clube', () {
    final tema = temaDoClube(
      const {
        'BkColor_Pri': '#112233',
        'BkColor_Sec': '#F4F4F4',
        'FontesGeral': 'Georgia',
        'BackGround': 'linear-gradient(180deg, #0076B7 0%, #005B9E 100%)',
        'ImgLogo': 'logo.png',
        'ImgFundo': 'https://cdn.exemplo/fundo.jpg',
      },
      baseImagens: 'imagens/',
      pagina: pagina,
    );

    expect(tema.primary, const Color(0xFF112233));
    expect(tema.surface, const Color(0xFFF4F4F4));
    expect(tema.buttonText, Colors.white);
    expect(tema.fontFamily, 'Georgia');
    expect(tema.background?.colors.first, const Color(0xFF0076B7));
    expect(tema.background?.colors.last, const Color(0xFF005B9E));
    expect(tema.logoUrl, 'https://cardapio.exemplo/imagens/logo.png');
    expect(tema.fundoUrl, 'https://cdn.exemplo/fundo.jpg');
  });

  test('cor do botão fica mais clara e menos saturada', () {
    const primaria = Color(0xFF005495);
    final botao = corBotao(primaria);
    final origem = HSLColor.fromColor(primaria);
    final ajustada = HSLColor.fromColor(botao);

    expect(ajustada.lightness, greaterThan(origem.lightness));
    expect(ajustada.saturation, lessThan(origem.saturation));
    expect(ajustada.saturation, greaterThan(origem.saturation * 0.5));
    expect(corLegivelNoFundo(botao, Colors.white), Colors.white);
    expect(raioBotao, 6);
  });

  test('foto relativa fica na pasta do PWA, não na raiz do site', () {
    final config = AppConfig.fromJson(const {
      'IpApiCardapio': 'https://cardapiosicom.azurewebsites.net/api/v1/',
      'BaseImagens': 'imagens/',
      'ExtProd': 'jpg',
    });
    final pagina = Uri.parse(
      'https://ftp.exemplo/solarium/index.html?70&2',
    );
    expect(
      config.urlFoto(22001, pagina: pagina),
      'https://ftp.exemplo/solarium/imagens/produtos/22001.jpg',
    );
    expect(
      resolverUrlImagem('logo.png', baseImagens: 'imagens/', pagina: pagina),
      'https://ftp.exemplo/solarium/imagens/logo.png',
    );
  });

  test('caminho relativo não duplica a pasta e URL pronta permanece', () {
    expect(
      resolverUrlImagem(
        'imagens/logo.png',
        baseImagens: 'imagens/',
        pagina: pagina,
      ),
      'https://cardapio.exemplo/imagens/logo.png',
    );
    expect(
      resolverUrlImagem(
        'logo.png',
        baseImagens: 'https://cdn.exemplo/fotos/',
        pagina: pagina,
      ),
      'https://cdn.exemplo/fotos/logo.png',
    );
    expect(
      resolverUrlImagem(
        'fotos/logo.png',
        baseImagens: 'https://cdn.exemplo/fotos/',
        pagina: pagina,
      ),
      'https://cdn.exemplo/fotos/logo.png',
    );
    expect(
      resolverUrlImagem('  ', baseImagens: 'imagens/', pagina: pagina),
      isNull,
    );
  });
}
