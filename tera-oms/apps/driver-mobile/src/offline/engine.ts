import * as SecureStore from 'expo-secure-store';
import Constants from 'expo-constants';
import { SyncEngine } from '@tera/offline-sync';
import { createExpoAdapter } from './adapter';

const KEY_DEVICE_ID = 'tera_device_id';
function getExtra(key: string, fallback: string): string {
  const extra = (Constants.expoConfig?.extra ?? {}) as Record<string, string>;
  return extra[key] ?? fallback;
}
function generateDeviceId(): string {
  return 'dev-' + Math.random().toString(36).slice(2) + Date.now().toString(36);
}
async function loadOrCreateDeviceId(): Promise<string> {
  const existing = await SecureStore.getItemAsync(KEY_DEVICE_ID);
  if (existing) return existing;
  const fresh = generateDeviceId();
  await SecureStore.setItemAsync(KEY_DEVICE_ID, fresh);
  return fresh;
}

let singleton: SyncEngine | null = null;
export async function getEngine(): Promise<SyncEngine> {
  if (singleton) return singleton;
  const adapter = await createExpoAdapter();
  const deviceId = await loadOrCreateDeviceId();
  singleton = new SyncEngine(adapter, {
    api_base_url: getExtra('apiUrl', 'http://10.0.2.2:8000'),
    device_id: deviceId,
    driver_id: getExtra('driverId', 'D-201'),
  });
  await singleton.init();
  return singleton;
}
