{{flutter_js}}
{{flutter_build_config}}

// No serviceWorkerSettings on purpose.
//
// The generated bootstrap registers Flutter's own flutter_service_worker.js,
// which is deprecated and only unregisters itself. Its registration races the
// hand-written playit-sw.js in index.html, and whichever loses makes
// prepareServiceWorker exceed its 4s budget, so the console fills with
// "Exception while loading service worker" even though the real worker
// activates fine.
//
// Leaving the settings out keeps playit-sw.js as the only worker, which is the
// one that actually serves the app shell and the cached API responses offline.
_flutter.loader.load();