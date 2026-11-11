'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter_bootstrap.js": "0889a39b2cfd68e14ed55c8091381ab7",
"version.json": "dd0193a2c9fccb8ceaff13150866542c",
"index.html": "15d268a4f5af167202f157715ee1bffb",
"/": "15d268a4f5af167202f157715ee1bffb",
"main.dart.js": "bbbad99d1349dedb0e06a32854a69597",
"flutter.js": "4b2350e14c6650ba82871f60906437ea",
"favicon.png": "781404f2099d2db3115cc9d34b74dc8d",
"icons/Icon-192.png": "6b231cb1cd855cfa63d3344764ed33b7",
"icons/Icon-maskable-192.png": "3341caebcd2e32010865a4c6b00db85c",
"icons/Icon-maskable-512.png": "927463b835ebfce5c997b8207cc06ed9",
"icons/Icon-512.png": "a706361a5dda64d093ed27e940328b0e",
"manifest.json": "bde9e148ea50539a5c223d2f4d601626",
"assets/AssetManifest.json": "1a1bfd62a6437b25ec43c3591c9c7957",
"assets/NOTICES": "f936e6ebd91f4986626ddb7cabd63da2",
"assets/FontManifest.json": "7b2a36307916a9721811788013e65289",
"assets/AssetManifest.bin.json": "7bd787986882233c2835a7b242636ae6",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin": "41a8720961bbf97584107755e932d950",
"assets/fonts/MaterialIcons-Regular.otf": "07c9314d90ec25b03eadb990abb937ea",
"assets/assets/config/config_cardapio.json": "b3518d4d4b20ed23797cfa35f2b9c7aa",
"assets/assets/images/logo.png": "eeacff967611dd87d1375fa71e2a48b4",
"assets/assets/images/produtos/228.jpg": "f6fc151a96f892c4fc0e0fd117956e33",
"assets/assets/images/produtos/215.jpg": "0723821c954b849b470e5cc3f64b0ac3",
"assets/assets/images/produtos/203.jpg": "ae0e585b145071b5c2b6516221076a0c",
"assets/assets/images/produtos/217.jpg": "b26c7c0b0e62e06b9de49e881f8637f2",
"assets/assets/images/produtos/3369.jpg": "82c75007da49af3684c5dfcd74ff6272",
"assets/assets/images/produtos/4012.jpg": "c4053ea4830076198a7eed57e933cbf0",
"assets/assets/images/produtos/210.jpg": "6e7ec6848d7b6812c6c7e4d9b97fa62d",
"assets/assets/images/produtos/14.jpg": "21397e3534a5b017570342cd642a1433",
"assets/assets/images/produtos/262.jpg": "de098208af09b6b84d1eb607265c4263",
"assets/assets/images/produtos/1331.jpg": "89bc0e2e159fe2140c6ffaf43897c3cb",
"assets/assets/images/produtos/17.jpg": "565d868b9750110747f1225d4a688537",
"assets/assets/images/produtos/260.jpg": "e98945138baffb24a638b964c5c0b740",
"assets/assets/images/produtos/261.jpg": "efc86f53d5eac944b37057c5ff5817ac",
"assets/assets/images/produtos/700.jpg": "5f662acfd21b36dfcc627387767006f7",
"assets/assets/images/produtos/930.jpg": "5edca971baeaa82210d61886781b6724",
"assets/assets/images/produtos/3116.jpg": "f90629acaabe7a5d68968112595fd890",
"assets/assets/images/produtos/524.jpg": "1f58b4580d7fdf42cc99895561518fe0",
"assets/assets/images/produtos/2433.jpg": "636fc23c0c50789517ad23f87d55fa0b",
"assets/assets/images/produtos/653.jpg": "fbc5265cbc72deb16d2e118df426f6f5",
"assets/assets/images/produtos/526.jpg": "58aa88d971f152636f8b7588caca91d1",
"assets/assets/images/produtos/33.jpg": "63cc71edac46df89463f7011ad70a95e",
"assets/assets/images/produtos/4079.jpg": "aa010c4ccf1769ae325bf0e7722765aa",
"assets/assets/images/produtos/2434.jpg": "123ef5b5a66940fe4c01796e5d8526c4",
"assets/assets/images/produtos/695.jpg": "4c86fbeb1468355c14a30796a46a65a3",
"assets/assets/images/produtos/3571.jpg": "611fc3afa2631feeecf092e644a60cb1",
"assets/assets/images/produtos/221.jpg": "7a1f6da9b8fc19670d9ab490393ba924",
"assets/assets/images/produtos/83.jpg": "4cf2f86daa7874279f6a221a9f105cb5",
"assets/assets/images/produtos/50.jpg": "0b71fb2b0d9ca7574a130c2b62e21945",
"assets/assets/images/produtos/1.jpg": "9448cc5432391995c4272597b905c328",
"assets/assets/images/produtos/218.jpg": "777d4c8e8ce85b42a1dc8e27b1cd26cc",
"canvaskit/skwasm.js": "ac0f73826b925320a1e9b0d3fd7da61c",
"canvaskit/skwasm.js.symbols": "96263e00e3c9bd9cd878ead867c04f3c",
"canvaskit/canvaskit.js.symbols": "efc2cd87d1ff6c586b7d4c7083063a40",
"canvaskit/skwasm.wasm": "828c26a0b1cc8eb1adacbdd0c5e8bcfa",
"canvaskit/chromium/canvaskit.js.symbols": "e115ddcfad5f5b98a90e389433606502",
"canvaskit/chromium/canvaskit.js": "b7ba6d908089f706772b2007c37e6da4",
"canvaskit/chromium/canvaskit.wasm": "ea5ab288728f7200f398f60089048b48",
"canvaskit/canvaskit.js": "26eef3024dbc64886b7f48e1b6fb05cf",
"canvaskit/canvaskit.wasm": "e7602c687313cfac5f495c5eac2fb324",
"canvaskit/skwasm.worker.js": "89990e8c92bcb123999aa81f7e203b1c"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
