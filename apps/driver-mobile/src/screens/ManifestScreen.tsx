import { useCallback, useEffect, useState } from 'react';
import { View, Text, ScrollView, Pressable, ActivityIndicator, StyleSheet, RefreshControl, Alert } from 'react-native';
import { useI18n } from '@tera/i18n';
import type { LocalManifest, LocalStop, ProofOutcome } from '@tera/offline-sync';
import { readManifest, recordStopAction } from '../offline/local';
import { getEngine } from '../offline/engine';
import { StopActionSheet, type SheetChoice } from './StopActionSheet';
import { EpodScreen } from './EpodScreen';

const EMPTY: LocalManifest = { plan: null, stops: [], counts: { total: 0, pending: 0, delivered: 0, failed: 0, paid: 0, unpaid: 0 } };

export function ManifestScreen() {
  const { t } = useI18n();
  const [manifest, setManifest] = useState<LocalManifest>(EMPTY);
  const [pendingOps, setPendingOps] = useState(0);
  const [refreshing, setRefreshing] = useState(false);
  const [syncing, setSyncing] = useState(false);
  const [banner, setBanner] = useState<{ kind: 'error' | 'info'; text: string } | null>(null);
  const [sheetStop, setSheetStop] = useState<LocalStop | null>(null);
  const [epodStop, setEpodStop] = useState<LocalStop | null>(null);
  const [epodOutcome, setEpodOutcome] = useState<ProofOutcome | null>(null);

  const refreshAll = useCallback(async () => {
    setManifest(await readManifest());
    const engine = await getEngine();
    setPendingOps(await engine.pendingCount());
  }, []);
  useEffect(() => { void refreshAll(); }, [refreshAll]);

  const doSync = useCallback(async (userTriggered = false) => {
    if (userTriggered) setBanner(null);
    setSyncing(true);
    try {
      const engine = await getEngine();
      const r = await engine.sync();
      await refreshAll();
      if (userTriggered) {
        if (r.errors.length > 0) setBanner({ kind: 'error', text: r.errors.join(' · ') });
        else setBanner({ kind: 'info', text: t('driver.manifest.sync_ok', { pulled: r.pulled, pushed: r.pushed }) });
      }
    } catch (e) {
      if (userTriggered) setBanner({ kind: 'error', text: e instanceof Error ? e.message : String(e) });
    } finally { setSyncing(false); }
  }, [refreshAll, t]);

  const onRefresh = useCallback(async () => {
    setRefreshing(true); await doSync(true); setRefreshing(false);
  }, [doSync]);

  const onChoose = useCallback((choice: SheetChoice) => {
    const stop = sheetStop;
    setSheetStop(null);
    if (!stop) return;
    if (choice.kind === 'status') {
      void (async () => {
        try {
          await recordStopAction(stop.id, choice.action);
          await refreshAll(); void doSync(false);
        } catch (e) { setBanner({ kind: 'error', text: e instanceof Error ? e.message : String(e) }); }
      })();
    } else {
      setEpodStop(stop); setEpodOutcome(choice.outcome);
    }
  }, [sheetStop, refreshAll, doSync]);

  const onEpodSaved = useCallback(async () => {
    setEpodStop(null); setEpodOutcome(null);
    await refreshAll(); void doSync(false);
  }, [refreshAll, doSync]);

  const { plan, stops, counts } = manifest;
  return (
    <>
      <ScrollView style={styles.root} contentContainerStyle={styles.content}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#0f766e" />}>
        <View style={styles.header}>
          <View style={{ flex: 1 }}>
            <Text style={styles.title}>{t('driver.manifest.title')}</Text>
            <Text style={styles.subtitle}>{plan ? `${plan.vehicle_id} · ${counts.total} ${t('dispatch.stops')}` : t('driver.manifest.not_synced')}</Text>
          </View>
          <Pressable onPress={() => doSync(true)} disabled={syncing}
            style={({ pressed }) => [styles.syncBtn, (pressed || syncing) && { opacity: 0.6 }]}>
            {syncing ? <ActivityIndicator color="#fff" size="small" />
              : <Text style={styles.syncBtnText}>{pendingOps > 0 ? `${pendingOps}` : t('driver.manifest.sync')}</Text>}
          </Pressable>
        </View>
        {banner && (
          <View style={banner.kind === 'error' ? styles.errorBox : styles.infoBox}>
            <Text style={banner.kind === 'error' ? styles.errorText : styles.infoText}>{banner.text}</Text>
          </View>
        )}
        {counts.total > 0 && (
          <View style={styles.progressRow}>
            <Stat label={t('driver.manifest.pending')} value={counts.pending} />
            <Stat label={t('driver.manifest.delivered')} value={counts.delivered} good />
            <Stat label={t('driver.manifest.failed')} value={counts.failed} bad={counts.failed > 0} />
            {counts.paid > 0 && <Stat label={t('driver.payment.paid')} value={counts.paid} good />}
          </View>
        )}
        {stops.length === 0 && (
          <View style={styles.emptyBox}>
            <Text style={styles.emptyText}>{plan ? t('driver.manifest.no_stops') : t('driver.manifest.empty')}</Text>
            <Text style={styles.muted}>{t('driver.manifest.empty_hint')}</Text>
          </View>
        )}
        {stops.map((s) => (
          <Pressable key={s.id} onPress={() => setSheetStop(s)}
            style={({ pressed }) => [styles.stopCard, pressed && { opacity: 0.7 }]}>
            <View style={[styles.seq, seqColor(s.status)]}><Text style={styles.seqText}>{s.seq}</Text></View>
            <View style={{ flex: 1 }}>
              <Text style={styles.stopName}>{s.distributor_name}</Text>
              <Text style={styles.muted}>{t('time.eta')} {new Date(s.planned_eta).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</Text>
              {s.payment_status !== 'NONE' && (
                <Text style={[styles.payBadge, s.payment_status === 'CONFIRMED' ? styles.payConfirmed : styles.payPending]}>
                  {s.payment_status === 'CONFIRMED'
                    ? `✓ ${s.payment_method === 'TELEBIRR' ? 'Telebirr' : 'Cash'} ${s.payment_amount_etb ?? 0}`
                    : `⏳ ${t('driver.payment.pending')}`}
                </Text>
              )}
            </View>
            <Text style={[styles.statusPill, statusColor(s.status)]}>{t(`driver.manifest.status.${s.status.toLowerCase()}`)}</Text>
          </Pressable>
        ))}
      </ScrollView>
      <StopActionSheet stop={sheetStop} onChoose={onChoose} onCancel={() => setSheetStop(null)} />
      <EpodScreen key={epodStop?.id ?? 'none'} stop={epodStop} outcome={epodOutcome}
        onClose={() => { setEpodStop(null); setEpodOutcome(null); }} onSaved={onEpodSaved} />
    </>
  );
}

function Stat({ label, value, good, bad }: { label: string; value: number; good?: boolean; bad?: boolean }) {
  const color = bad ? '#b91c1c' : good ? '#166534' : '#1a1a1a';
  return (
    <View style={styles.progressStat}>
      <Text style={[styles.progressValue, { color }]}>{value}</Text>
      <Text style={styles.progressLabel}>{label}</Text>
    </View>
  );
}
function seqColor(s: string) {
  if (s === 'DELIVERED') return { backgroundColor: '#166534' };
  if (s === 'FAILED') return { backgroundColor: '#b91c1c' };
  if (s === 'ARRIVED') return { backgroundColor: '#b45309' };
  return { backgroundColor: '#6b6b6b' };
}
function statusColor(s: string) {
  if (s === 'DELIVERED') return { color: '#166534', backgroundColor: '#f0fdf4' };
  if (s === 'FAILED') return { color: '#b91c1c', backgroundColor: '#fef2f2' };
  if (s === 'ARRIVED') return { color: '#b45309', backgroundColor: '#fffbeb' };
  return { color: '#6b6b6b', backgroundColor: '#f3f3f3' };
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#fafaf7' },
  content: { padding: 16, paddingBottom: 96 },
  header: { flexDirection: 'row', alignItems: 'center', marginBottom: 12 },
  title: { fontSize: 22, fontWeight: '700', color: '#1a1a1a' },
  subtitle: { fontSize: 13, color: '#6b6b6b', marginTop: 2 },
  syncBtn: { backgroundColor: '#0f766e', paddingHorizontal: 14, paddingVertical: 10, borderRadius: 10, minWidth: 64, alignItems: 'center' },
  syncBtnText: { color: '#fff', fontWeight: '600', fontSize: 14 },
  infoBox: { backgroundColor: '#ecfdf5', borderColor: '#6ee7b7', borderWidth: 1, borderRadius: 8, padding: 10, marginBottom: 12 },
  infoText: { color: '#065f46', fontSize: 13 },
  errorBox: { backgroundColor: '#fef2f2', borderColor: '#fca5a5', borderWidth: 1, borderRadius: 8, padding: 10, marginBottom: 12 },
  errorText: { color: '#b91c1c', fontSize: 13 },
  progressRow: { flexDirection: 'row', gap: 8, marginBottom: 12, backgroundColor: '#fff', borderWidth: 1, borderColor: '#e5e5e0', borderRadius: 10, padding: 12 },
  progressStat: { flex: 1, alignItems: 'center' },
  progressValue: { fontSize: 20, fontWeight: '700' },
  progressLabel: { fontSize: 10, color: '#6b6b6b', marginTop: 2 },
  emptyBox: { paddingVertical: 40, alignItems: 'center' },
  emptyText: { fontSize: 15, color: '#1a1a1a', fontWeight: '500' },
  muted: { fontSize: 12, color: '#6b6b6b', marginTop: 2 },
  stopCard: { flexDirection: 'row', alignItems: 'center', backgroundColor: '#fff', borderWidth: 1, borderColor: '#e5e5e0', borderRadius: 10, padding: 12, marginBottom: 8 },
  seq: { width: 34, height: 34, borderRadius: 17, alignItems: 'center', justifyContent: 'center', marginRight: 12 },
  seqText: { color: '#fff', fontWeight: '700', fontSize: 14 },
  stopName: { fontSize: 15, fontWeight: '500', color: '#1a1a1a' },
  statusPill: { fontSize: 11, fontWeight: '500', paddingHorizontal: 8, paddingVertical: 3, borderRadius: 999, overflow: 'hidden' },
  payBadge: { fontSize: 11, fontWeight: '500', paddingHorizontal: 6, paddingVertical: 2, borderRadius: 6, marginTop: 4, overflow: 'hidden', alignSelf: 'flex-start' },
  payConfirmed: { backgroundColor: '#f0fdf4', color: '#166534' },
  payPending: { backgroundColor: '#fffbeb', color: '#b45309' },
});
