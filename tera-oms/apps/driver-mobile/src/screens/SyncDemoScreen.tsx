import { useCallback, useEffect, useState } from 'react';
import { View, Text, ScrollView, Pressable, ActivityIndicator, StyleSheet, RefreshControl } from 'react-native';
import { useI18n } from '@tera/i18n';
import { getEngine } from '../offline/engine';
import { createExpoAdapter } from '../offline/adapter';

export function SyncDemoScreen() {
  const { t } = useI18n();
  const [status, setStatus] = useState({ clientId: null as string | null, cursor: '0', lastSyncedAt: null as string | null, pending: 0, syncing: false, error: null as string | null });
  const [stops, setStops] = useState<any[]>([]);
  const [plan, setPlan] = useState<any>(null);

  const refresh = useCallback(async () => {
    const engine = await getEngine();
    const state = await engine.getState();
    const pending = await engine.pendingCount();
    const adapter = await createExpoAdapter();
    const plans = await adapter.all(`SELECT id, vehicle_id, status FROM route_plan LIMIT 1`);
    const ss = await adapter.all(`SELECT id, seq, distributor_name, status, planned_eta FROM route_stop ORDER BY seq ASC`);
    setStatus((s) => ({ ...s, clientId: state.client_id, cursor: state.last_cursor, lastSyncedAt: state.last_synced_at, pending }));
    setPlan(plans[0] ?? null);
    setStops(ss);
  }, []);

  useEffect(() => { void refresh(); }, [refresh]);

  const runSync = async () => {
    setStatus((s) => ({ ...s, syncing: true, error: null }));
    try {
      const engine = await getEngine();
      const r = await engine.sync();
      await refresh();
      setStatus((s) => ({ ...s, syncing: false, error: r.errors.length > 0 ? r.errors.join(' · ') : null }));
    } catch (e) {
      setStatus((s) => ({ ...s, syncing: false, error: e instanceof Error ? e.message : String(e) }));
    }
  };

  return (
    <ScrollView style={styles.root} contentContainerStyle={styles.content}
      refreshControl={<RefreshControl refreshing={status.syncing} onRefresh={runSync} />}>
      <Text style={styles.title}>{t('driver.sync.title')}</Text>
      <Text style={styles.subtitle}>{t('driver.sync.subtitle')}</Text>
      <View style={styles.card}>
        <Row label={t('driver.sync.device')} value={status.clientId ?? '—'} mono />
        <Row label={t('driver.sync.cursor')} value={status.cursor} mono />
        <Row label={t('driver.sync.last_sync')} value={status.lastSyncedAt ? new Date(status.lastSyncedAt).toLocaleTimeString() : '—'} />
        <Row label={t('driver.sync.pending')} value={String(status.pending)} />
      </View>
      <Pressable onPress={runSync} disabled={status.syncing}
        style={({ pressed }) => [styles.button, (pressed || status.syncing) && { opacity: 0.7 }]}>
        {status.syncing ? <ActivityIndicator color="#fff" /> : <Text style={styles.buttonText}>{t('driver.sync.now')}</Text>}
      </Pressable>
      {status.error && <View style={styles.errorBox}><Text style={styles.errorText}>{status.error}</Text></View>}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>{t('driver.sync.manifest')}</Text>
        {plan ? (
          <>
            <Text style={styles.muted}>{plan.vehicle_id} · {plan.status} · {stops.length} stops</Text>
            {stops.map((s) => (
              <View key={s.id} style={styles.stopRow}>
                <Text style={styles.stopSeq}>{s.seq}</Text>
                <View style={{ flex: 1 }}>
                  <Text style={styles.stopName}>{s.distributor_name}</Text>
                  <Text style={styles.muted}>{new Date(s.planned_eta).toLocaleTimeString()}</Text>
                </View>
                <Text style={styles.statusPill}>{s.status}</Text>
              </View>
            ))}
          </>
        ) : <Text style={styles.muted}>{t('driver.sync.empty')}</Text>}
      </View>
    </ScrollView>
  );
}

function Row({ label, value, mono }: { label: string; value: string; mono?: boolean }) {
  return (
    <View style={styles.stat}>
      <Text style={styles.statLabel}>{label}</Text>
      <Text style={[styles.statValue, mono && { fontFamily: 'monospace' }]} numberOfLines={1}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#fafaf7' },
  content: { padding: 16, paddingBottom: 48 },
  title: { fontSize: 24, fontWeight: '700', color: '#1a1a1a', marginTop: 8 },
  subtitle: { fontSize: 14, color: '#6b6b6b', marginTop: 4, marginBottom: 16 },
  card: { backgroundColor: '#fff', borderWidth: 1, borderColor: '#e5e5e0', borderRadius: 10, padding: 12, marginBottom: 12 },
  stat: { paddingVertical: 6, borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: '#eee', flexDirection: 'row', justifyContent: 'space-between' },
  statLabel: { fontSize: 13, color: '#6b6b6b' },
  statValue: { fontSize: 13, color: '#1a1a1a', maxWidth: '60%' },
  button: { backgroundColor: '#0f766e', borderRadius: 10, paddingVertical: 14, alignItems: 'center', marginVertical: 8 },
  buttonText: { color: '#fff', fontWeight: '600', fontSize: 16 },
  errorBox: { backgroundColor: '#fef2f2', borderColor: '#fca5a5', borderWidth: 1, borderRadius: 8, padding: 10, marginTop: 8 },
  errorText: { color: '#b91c1c', fontSize: 13 },
  section: { marginTop: 16 },
  sectionTitle: { fontSize: 16, fontWeight: '600', color: '#1a1a1a', marginBottom: 8 },
  muted: { fontSize: 12, color: '#6b6b6b' },
  stopRow: { flexDirection: 'row', alignItems: 'center', backgroundColor: '#fff', borderWidth: 1, borderColor: '#e5e5e0', borderRadius: 8, padding: 10, marginTop: 6 },
  stopSeq: { width: 24, height: 24, textAlign: 'center', lineHeight: 24, borderRadius: 12, backgroundColor: '#f3f3f3', color: '#1a1a1a', fontWeight: '600', marginRight: 10, fontSize: 12 },
  stopName: { fontSize: 14, fontWeight: '500', color: '#1a1a1a' },
  statusPill: { fontSize: 11, fontWeight: '500', paddingHorizontal: 8, paddingVertical: 3, borderRadius: 999, backgroundColor: '#f3f3f3', color: '#6b6b6b' },
});
