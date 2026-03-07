// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails";
import "controllers";

// Detect if running in an iframe (e.g. inside Fluxo)
if (window.self !== window.top) {
  document.documentElement.classList.add('in-iframe');
}

Turbo.StreamActions.redirect = function () {
  Turbo.visit(this.target);
};

// Register service worker for PWA offline support
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/service-worker')
      .then(registration => {
        console.log('Service Worker registered with scope:', registration.scope);
      })
      .catch(error => {
        console.log('Service Worker registration failed:', error);
      });
  });
}
