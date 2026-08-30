// ============================================================
// offline-db.js — IndexedDB for Offline-First PWA
// Store RPC responses locally so app works without network
// ============================================================

const DB_NAME = 'insightwos-offline';
const DB_VERSION = 1;
const STORE_NAME = 'rpc-cache';

let dbInstance = null;

function openDB() {
  if (dbInstance) return Promise.resolve(dbInstance);

  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);

    request.onupgradeneeded = (event) => {
      const db = event.target.result;
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        const store = db.createObjectStore(STORE_NAME, { keyPath: 'key' });
        store.createIndex('expires', 'expires', { unique: false });
        store.createIndex('timestamp', 'timestamp', { unique: false });
      }
    };

    request.onsuccess = (event) => {
      dbInstance = event.target.result;
      resolve(dbInstance);
    };

    request.onerror = () => reject(request.error);
  });
}

/**
 * Get cached data from IndexedDB
 * @param {string} key - Cache key (e.g. "rpc:admin_get_summary")
 * @returns {Promise<any|null>} Cached data or null
 */
export async function offlineGet(key) {
  try {
    const db = await openDB();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, 'readonly');
      const store = tx.objectStore(STORE_NAME);
      const req = store.get(key);

      req.onsuccess = () => {
        const result = req.result;
        if (!result) return resolve(null);

        // Check expiry
        if (result.expires && Date.now() > result.expires) {
          // Don't delete here — lazy cleanup
          return resolve(null);
        }
        resolve(result.data);
      };
      req.onerror = () => resolve(null);
    });
  } catch {
    return null;
  }
}

/**
 * Store data in IndexedDB
 * @param {string} key - Cache key
 * @param {any} data - Data to store
 * @param {number} ttlMs - Time to live in milliseconds (default: 10 minutes)
 */
export async function offlineSet(key, data, ttlMs = 600000) {
  try {
    const db = await openDB();
    return new Promise((resolve) => {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      const store = tx.objectStore(STORE_NAME);
      store.put({
        key,
        data,
        expires: Date.now() + ttlMs,
        timestamp: new Date().toISOString(),
      });
      tx.oncomplete = () => resolve(true);
      tx.onerror = () => resolve(false);
    });
  } catch {
    return false;
  }
}

/**
 * Delete a specific cache entry
 */
export async function offlineDelete(key) {
  try {
    const db = await openDB();
    return new Promise((resolve) => {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      tx.objectStore(STORE_NAME).delete(key);
      tx.oncomplete = () => resolve(true);
      tx.onerror = () => resolve(false);
    });
  } catch {
    return false;
  }
}

/**
 * Clear all expired entries (lazy cleanup)
 */
export async function offlineCleanup() {
  try {
    const db = await openDB();
    return new Promise((resolve) => {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      const store = tx.objectStore(STORE_NAME);
      const index = store.index('expires');
      const range = IDBKeyRange.upperBound(Date.now());
      const req = index.openCursor(range);

      let count = 0;
      req.onsuccess = (event) => {
        const cursor = event.target.result;
        if (cursor) {
          cursor.delete();
          count++;
          cursor.continue();
        }
      };
      tx.oncomplete = () => resolve(count);
      tx.onerror = () => resolve(0);
    });
  } catch {
    return 0;
  }
}

/**
 * Get all cached keys (for debug/display)
 */
export async function offlineKeys() {
  try {
    const db = await openDB();
    return new Promise((resolve) => {
      const tx = db.transaction(STORE_NAME, 'readonly');
      const req = tx.objectStore(STORE_NAME).getAllKeys();
      req.onsuccess = () => resolve(req.result || []);
      req.onerror = () => resolve([]);
    });
  } catch {
    return [];
  }
}

/**
 * Cached RPC call — tries network first, falls back to IndexedDB
 * @param {Function} rpcFn - Async function that calls Supabase RPC
 * @param {string} cacheKey - Cache key
 * @param {number} ttlMs - TTL in ms
 * @returns {Promise<{data: any, fromCache: boolean}>}
 */
export async function cachedRpc(rpcFn, cacheKey, ttlMs = 600000) {
  try {
    const { data, error } = await rpcFn();
    if (!error && data) {
      await offlineSet(cacheKey, data, ttlMs);
      return { data, fromCache: false };
    }
  } catch {
    // Network failed — try cache
  }

  const cached = await offlineGet(cacheKey);
  if (cached) {
    return { data: cached, fromCache: true };
  }

  return { data: null, fromCache: false };
}

// Run cleanup every 5 minutes
if (typeof window !== 'undefined') {
  setInterval(() => offlineCleanup(), 300000);
}
