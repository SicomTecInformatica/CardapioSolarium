/// Pede ao browser para revalidar o GET. O service worker do Flutter
/// continua cacheando só o app; pedido, mesa, produto e foto não ficam
/// horas parados nesse cache.
const cabecalhosSemCache = {
  'Cache-Control': 'no-cache',
  'Pragma': 'no-cache',
};
