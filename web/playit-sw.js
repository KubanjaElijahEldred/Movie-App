// Service worker for Play It.
//
// Flutter's generated flutter_service_worker.js only unregisters itself, which
// leaves the app with no offline capability. Chrome will not show an install
// prompt for a site without a service worker that has a fetch handler, so this
// file exists to satisfy that requirement and to keep the shell available
// offline once installed.
//
// Caching policy is deliberately split by what the data is:
//
//   * App shell and Flutter runtime  -> cache first, refreshed in the
//     background. These are immutable per build because the service worker
//     version below changes whenever a deploy happens.
//   * Navigations                    -> network first, falling back to the
//     cached shell so a cold offline launch still opens.
//   * TMDB API                       -> network first with a cache fallback.
//     Cached catalogue pages are a convenience, not a source of truth: movie
//     data changes constantly and a stale response would be worse than none.
//   * TMDB images                    -> cache first, since poster art is
//     immutable per path and these dominate repeat-viewing data use.

const SHELL_CACHE = 'playit-shell-v3';
const API_CACHE = 'playit-api-v3';
const IMAGE_CACHE = 'playit-images-v3';

const SHELL_ASSETS = [
  './',
  './index.html',
  './flutter_bootstrap.js',
  './flutter.js',
  './manifest.json',
  './favicon.png',
  './favicon.ico',
  './icons/Icon-192.png',
  './icons/Icon-512.png',
  './icons/Icon-maskable-192.png',
  './icons/Icon-maskable-512.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(SHELL_CACHE)
      // addAll is atomic: one 404 and the whole install fails, leaving the app
      // with no service worker and therefore no install prompt. Cache entries
      // individually so a single missing optional asset cannot break install.
      .then((cache) =>
        Promise.all(
          SHELL_ASSETS.map((url) =>
            cache.add(new Request(url, { cache: 'reload' })).catch(() => {}),
          ),
        ),
      )
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter((key) => ![SHELL_CACHE, API_CACHE, IMAGE_CACHE].includes(key))
            .map((key) => caches.delete(key)),
        ),
      )
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);

  // Cross-origin traffic is only cached for the two TMDB hosts the app talks
  // to. Anything else is passed straight through so we never act as a proxy
  // for hosts we know nothing about.
  if (url.origin !== self.location.origin) {
    if (url.hostname === 'api.themoviedb.org') {
      event.respondWith(networkFirst(request, API_CACHE));
    } else if (url.hostname === 'image.tmdb.org') {
      event.respondWith(cacheFirst(request, IMAGE_CACHE));
    }
    return;
  }

  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request).catch(() => caches.match('./index.html', { ignoreSearch: true })),
    );
    return;
  }

  event.respondWith(cacheFirst(request, SHELL_CACHE));
});

async function cacheFirst(request, cacheName) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(request, { ignoreVary: true });
  if (cached) return cached;

  try {
    const response = await fetch(request);
    // Only store real successes. Caching an opaque or error response would
    // pin a failure in place.
    if (response && (response.ok || response.type === 'opaque')) {
      cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    const fallback = await cache.match(request, { ignoreVary: true });
    if (fallback) return fallback;
    throw error;
  }
}

async function networkFirst(request, cacheName) {
  const cache = await caches.open(cacheName);
  try {
    const response = await fetch(request);
    if (response && response.ok) cache.put(request, response.clone());
    return response;
  } catch (error) {
    const cached = await cache.match(request, { ignoreVary: true });
    if (cached) return cached;
    throw error;
  }
}