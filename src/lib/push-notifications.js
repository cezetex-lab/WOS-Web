// ============================================================
// push-notifications.js — Web Push Notification Support
// Register SW, subscribe to push, handle incoming notifications
// ============================================================

/**
 * Register service worker for push notifications
 */
export async function registerServiceWorker() {
  if (!('serviceWorker' in navigator)) {
    return null;
  }

  try {
    const registration = await navigator.serviceWorker.register('/sw.js', {
      scope: '/',
    });
    return registration;
  } catch (e) {
    return null;
  }
}

/**
 * Check if push notifications are supported and permitted
 */
export function isPushSupported() {
  return (
    'Notification' in window &&
    'serviceWorker' in navigator &&
    'PushManager' in window
  );
}

/**
 * Get current notification permission status
 */
export function getPermissionStatus() {
  if (!isPushSupported()) return 'unsupported';
  return Notification.permission; // 'granted', 'denied', 'default'
}

/**
 * Request notification permission
 */
export async function requestPermission() {
  if (!isPushSupported()) return 'unsupported';

  if (Notification.permission === 'granted') return 'granted';
  if (Notification.permission === 'denied') return 'denied';

  const result = await Notification.requestPermission();
  return result;
}

/**
 * Subscribe to push notifications
 * @param {string} vapidPublicKey - VAPID public key (generate at https://app.pair.coach/variables)
 */
export async function subscribeToPush(vapidPublicKey) {
  try {
    const registration = await navigator.serviceWorker.ready;

    // Check existing subscription
    let subscription = await registration.pushManager.getSubscription();

    if (!subscription) {
      // Create new subscription
      subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(vapidPublicKey),
      });
    }
    return subscription;
  } catch (e) {
    return null;
  }
}

/**
 * Unsubscribe from push notifications
 */
export async function unsubscribeFromPush() {
  try {
    const registration = await navigator.serviceWorker.ready;
    const subscription = await registration.pushManager.getSubscription();

    if (subscription) {
      await subscription.unsubscribe();
      return true;
    }
    return false;
  } catch (e) {
    return false;
  }
}

/**
 * Send a local notification (no server needed)
 * @param {string} title
 * @param {object} options - { body, icon, badge, tag }
 */
export function sendLocalNotification(title, options = {}) {
  if (Notification.permission !== 'granted') return;

  try {
    new Notification(title, {
      body: options.body || '',
      icon: options.icon || '/icons/icon-192.png',
      badge: options.badge || '/icons/icon-96.png',
      tag: options.tag || 'insightwos-' + Date.now(),
      vibrate: [200, 100, 200],
      ...options,
    });
  } catch (e) { }
}

/**
 * Helper: Convert VAPID key to Uint8Array
 */
function urlBase64ToUint8Array(base64String) {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
  const rawData = window.atob(base64);
  const outputArray = new Uint8Array(rawData.length);
  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i);
  }
  return outputArray;
}

/**
 * Initialize push notifications for the app
 * Call this once when app loads
 */
export async function initPushNotifications() {
  const registration = await registerServiceWorker();
  if (!registration) return;

  const status = getPermissionStatus();
  if (status === 'granted') {
    // Already subscribed — check
    const existing = await registration.pushManager.getSubscription();
    if (existing) {
    }
  }

  return registration;
}
