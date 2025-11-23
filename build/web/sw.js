// Service Worker for Sijilli PWA
const CACHE_NAME = 'sijilli-v1.0.1';
const urlsToCache = [
  '/',
  '/main.dart.js',
  '/flutter_bootstrap.js',
  '/manifest.json',
  '/favicon.png',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/icons/Icon-maskable-192.png',
  '/icons/Icon-maskable-512.png'
];

// Install event
self.addEventListener('install', (event) => {
  console.log('Service Worker: Installing...');
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('Service Worker: Caching files');
        return cache.addAll(urlsToCache);
      })
      .then(() => {
        console.log('Service Worker: Installed successfully');
        // Don't skip waiting automatically - wait for user confirmation
      })
  );
});

// Activate event
self.addEventListener('activate', (event) => {
  console.log('Service Worker: Activating...');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            console.log('Service Worker: Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    }).then(() => {
      console.log('Service Worker: Activated successfully');
      // Take control of all clients immediately
      return self.clients.claim();
    })
  );
});

// Fetch event
self.addEventListener('fetch', (event) => {
  // Skip non-GET requests
  if (event.request.method !== 'GET') {
    return;
  }

  // Skip external requests
  if (!event.request.url.startsWith(self.location.origin)) {
    return;
  }

  event.respondWith(
    caches.match(event.request)
      .then((response) => {
        // Return cached version if available
        if (response) {
          return response;
        }

        // Fetch from network
        return fetch(event.request).then((response) => {
          // Don't cache if not a valid response
          if (!response || response.status !== 200 || response.type !== 'basic') {
            return response;
          }

          // Clone the response
          const responseToCache = response.clone();

          // Add to cache
          caches.open(CACHE_NAME)
            .then((cache) => {
              cache.put(event.request, responseToCache);
            });

          return response;
        });
      })
      .catch(() => {
        // Return offline page if available
        if (event.request.destination === 'document') {
          return caches.match('/');
        }
      })
  );
});

// Background sync for offline functionality
self.addEventListener('sync', (event) => {
  if (event.tag === 'background-sync') {
    console.log('Service Worker: Background sync triggered');
    event.waitUntil(
      // Notify the app that sync is available
      self.clients.matchAll().then((clients) => {
        clients.forEach((client) => {
          client.postMessage({
            type: 'BACKGROUND_SYNC',
            payload: 'sync-available'
          });
        });
      })
    );
  }
});

// Push notifications (for future use)
self.addEventListener('push', (event) => {
  console.log('Service Worker: Push notification received');
  
  const options = {
    body: event.data ? event.data.text() : 'إشعار جديد من سجلي',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    vibrate: [200, 100, 200],
    data: {
      url: '/'
    },
    actions: [
      {
        action: 'open',
        title: 'فتح التطبيق',
        icon: '/icons/Icon-192.png'
      },
      {
        action: 'close',
        title: 'إغلاق',
        icon: '/icons/Icon-192.png'
      }
    ]
  };

  event.waitUntil(
    self.registration.showNotification('سجلي', options)
  );
});

// Notification click
self.addEventListener('notificationclick', (event) => {
  console.log('Service Worker: Notification clicked');
  
  event.notification.close();

  if (event.action === 'open' || !event.action) {
    event.waitUntil(
      self.clients.matchAll().then((clients) => {
        // Check if app is already open
        for (const client of clients) {
          if (client.url === '/' && 'focus' in client) {
            return client.focus();
          }
        }
        
        // Open new window if app is not open
        if (self.clients.openWindow) {
          return self.clients.openWindow('/');
        }
      })
    );
  }
});

// Message handling
self.addEventListener('message', (event) => {
  console.log('Service Worker: Message received:', event.data);

  if (event.data && event.data.type === 'SKIP_WAITING') {
    console.log('Service Worker: Skipping waiting...');
    self.skipWaiting();
  }
});
