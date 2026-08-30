// ============================================================
// sync-queue.js — Background Sync for Offline Writes
// Queues mutations (create/update/delete) when offline
// Replays them when connection is restored
// ============================================================

const QUEUE_KEY = 'wos_sync_queue';
const MAX_RETRIES = 3;

/**
 * Add an operation to the sync queue
 * @param {object} op - { type, rpc, params, timestamp }
 */
export function enqueue(op) {
  try {
    const queue = getQueue();
    queue.push({
      ...op,
      id: Date.now() + '-' + Math.random().toString(36).slice(2, 6),
      retries: 0,
      timestamp: new Date().toISOString(),
    });
    localStorage.setItem(QUEUE_KEY, JSON.stringify(queue));
  } catch (e) {
    console.warn('Sync queue enqueue error:', e);
  }
}

/**
 * Get all queued operations
 */
export function getQueue() {
  try {
    return JSON.parse(localStorage.getItem(QUEUE_KEY) || '[]');
  } catch {
    return [];
  }
}

/**
 * Remove an operation from the queue
 */
function dequeue(id) {
  try {
    const queue = getQueue().filter(op => op.id !== id);
    localStorage.setItem(QUEUE_KEY, JSON.stringify(queue));
  } catch (e) {
    console.warn('Sync queue dequeue error:', e);
  }
}

/**
 * Get queue count
 */
export function getQueueCount() {
  return getQueue().length;
}

/**
 * Process the queue — called when online
 * @param {Function} rpcFn - The Supabase RPC caller function
 * @returns {Promise<{synced: number, failed: number}>}
 */
export async function processQueue(rpcFn) {
  const queue = getQueue();
  let synced = 0;
  let failed = 0;

  for (const op of queue) {
    try {
      const { error } = await rpcFn(op.rpc, op.params);
      if (!error) {
        dequeue(op.id);
        synced++;
      } else {
        op.retries = (op.retries || 0) + 1;
        if (op.retries >= MAX_RETRIES) {
          dequeue(op.id);
          failed++;
          console.warn(`Sync queue: max retries for ${op.rpc}`, error);
        }
      }
    } catch {
      op.retries = (op.retries || 0) + 1;
      if (op.retries >= MAX_RETRIES) {
        dequeue(op.id);
        failed++;
      }
    }
  }

  // Update remaining queue with retry counts
  try {
    localStorage.setItem(QUEUE_KEY, JSON.stringify(getQueue()));
  } catch {}

  return { synced, failed };
}

/**
 * Clear the entire queue
 */
export function clearQueue() {
  localStorage.removeItem(QUEUE_KEY);
}

// Auto-process queue when coming back online
if (typeof window !== 'undefined') {
  window.addEventListener('online', async () => {
    const count = getQueueCount();
    if (count > 0) {
      console.log(`[SyncQueue] Back online — processing ${count} queued operations`);
      // Import supabase dynamically to avoid circular deps
      try {
        const { supabase } = await import('./supabase-browser');
        await processQueue((rpc, params) => supabase.rpc(rpc, params));
      } catch (e) {
        console.warn('[SyncQueue] Auto-process error:', e);
      }
    }
  });
}
