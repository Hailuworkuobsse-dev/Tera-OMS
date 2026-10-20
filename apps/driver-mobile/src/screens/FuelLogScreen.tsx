import { useCallback, useEffect, useMemo, useState } from 'react';
import { View, Text, ScrollView, Pressable, TextInput, ActivityIndicator, StyleSheet, Alert, RefreshControl } from 'react-native';
import { useI18n } from '@tera/i18n';
import type { FuelContext, LocalFuelFill } from '@tera/offline-sync';
import { computeFuelHint } from '@tera/offline-sync';
import { readFuelContext, recordFuelLog } from '../offline/local';
import { getEngine } from '../offline/engine';
import Constants from 'expo-constants';

const DRIVER_ID = (Constants.expoConfig?.extra as any)?.driverId ?? 'D-201';
const EMPTY_CTX: FuelContext = { vehicle: null, last_fill: null, recent_fills: [] };

export function FuelLogScreen() {
  const { t } = useI18n();
  const [ctx, setCtx] = useState<FuelContext>(EMPTY_CTX);
  const [refreshing, setRefreshing] = useState(false);
  const [syncing, setSyncing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [pending, setPending] = useState(0);
  const [banner, setBanner] = useState<{ kind: 'error' | 'info'; text: string } | null>(null);
  const [liters, setLiters] = useState('');
  const [amount, setAmount] = useState('');
  const [odometer, setOdometer] = useState('');
  const [station, setStation] = useState('');

  const refreshAll = useCallback(async () => {
    setCtx(await readFuelContext());
    const engine = await getEngine();
    setPending(await engine.pendingCount());
  }, []);
  useEffect(() => { void refreshAll(); }, [refreshAll]);

  const doSync = useCallback(async (trig = false) => {
    if (trig) setBanner(null);
    setSyncing(true);
    try {
      const engine = await getEngine();
      const r = await engine.sync();
      await refreshAll();
      if (trig) setBanner(r.errors.length > 0 ? { kind: 'error', text: r.errors.join(' · ') } : { kind: 'info', text: `+${r.pulled} ↓ ${r.pushed} ↑` });
    } catch (e) {
      if (trig) setBanner({ kind: 'error', text: e instanceof Error ? e.message : String(e) });
    } finally { setSyncing(false); }
  }, [refreshAll]);

  const onRefresh = useCallback(async () => {
    setRefreshing(true); await doSync(true); setRefreshing(false);
  }, [doSync]);

  const previewHint = useMemo(() => {
    const l = parseFloat(liters); const o = parseFloat(odometer);
    if (!Number.isFinite(l) || l <= 0) return null;
    if (!Number.isFinite(o) || o <= 0) return null;
    return computeFuelHint({ liters: l, odometer_km: o, prev_odometer_km: ctx.last_fill?.odometer_km ?? null, baseline_l_per_100km: ctx.vehicle?.baseline_l_per_100km ?? null });
  }, [liters, odometer, ctx]);

  const litersN = parseFloat(liters); const amountN = parseFloat(amount); const odoN = parseFloat(odometer);
  const canSave = ctx.vehicle !== null && Number.isFinite(litersN) && litersN > 0 && Number.isFinite(amountN) && amountN > 0
    && Number.isFinite(odoN) && odoN > 0 && station.trim().length > 0 && (ctx.last_fill === null || odoN > ctx.last_fill.odometer_km) && !saving;

  const save = useCallback(async () => {
    if (!ctx.vehicle || !canSave) return;
    setSaving(true);
    try {
      const hint = await recordFuelLog({ vehicleId: ctx.vehicle.id, driverId: DRIVER_ID, liters: litersN, amountEtb: amountN, odometerKm: odoN, stationName: station.trim(), stationId: null });
      setLiters(''); setAmount(''); setOdometer(''); setStation('');
      await refreshAll(); void doSync(false);
      if (hint.level === 'high') Alert.alert(t('driver.fuel.variance_high'), t('driver.fuel.variance_high_body'));
      else if (hint.level === 'low') Alert.alert(t('driver.fuel.variance_low'), t('driver.fuel.variance_low_body'));
    } catch (e) { Alert.alert(t('common.error'), e instanceof Error ? e.message : String(e)); }
    finally { setSaving(false); }
  }, [ctx, canSave, litersN, amountN, odoN, station, refreshAll, doSync, t]);

  const { vehicle, last_fill, recent_fills } = ctx;
  return (
    <ScrollView style={styles.root} contentContainerStyle={styles.content}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#0f766e" />}
      keyboardShouldPersistTaps="handled">
      <View style={styles.header}>
        <View style={{ flex: 1 }}>
          <Text style={styles.title}>{t('driver.fuel.title')}</Text>
          <Text style={styles.subtitle}>{vehicle ? `${vehicle.plate}${vehicle.baseline_l_per_100km ? ` · ${t('driver.fuel.baseline')}: ${vehicle.baseline_l_per_100km} L/100km` : ''}` : t('driver.fuel.no_vehicle')}</Text>
        </View>
        <Pressable onPress={() => doSync(true)} disabled={syncing}
          style={({ pressed }) => [styles.syncBtn, (pressed || syncing) && { opacity: 0.6 }]}>
          {syncing ? <ActivityIndicator color="#fff" size="small" /> : <Text style={styles.syncBtnText}>{pending > 0 ? `${pending}` : t('driver.manifest.sync')}</Text>}
        </Pressable>
      </View>
      {banner && <View style={banner.kind === 'error' ? styles.errorBox : styles.infoBox}><Text style={banner.kind === 'error' ? styles.errorText : styles.infoText}>{banner.text}</Text></View>}
      {last_fill && (
        <View style={styles.lastFillBox}>
          <Text style={styles.sectionTitle}>{t('driver.fuel.last_fill')}</Text>
          <Text style={styles.muted}>{new Date(last_fill.captured_at).toLocaleString()} · {last_fill.odometer_km.toFixed(0)} km · {last_fill.liters} L</Text>
        </View>
      )}
      <View style={styles.card}>
        <Text style={styles.sectionTitle}>{t('driver.fuel.new_fill')}</Text>
        <Text style={styles.label}>{t('driver.fuel.liters')}</Text>
        <TextInput value={liters} onChangeText={setLiters} keyboardType="decimal-pad" placeholder="0.00" style={styles.input} editable={!saving} />
        <Text style={[styles.label, { marginTop: 12 }]}>{t('driver.fuel.amount')}</Text>
        <TextInput value={amount} onChangeText={setAmount} keyboardType="decimal-pad" placeholder="0.00" style={styles.input} editable={!saving} />
        <Text style={[styles.label, { marginTop: 12 }]}>{t('driver.fuel.odometer')}</Text>
        <TextInput value={odometer} onChangeText={setOdometer} keyboardType="decimal-pad" placeholder={last_fill ? `> ${last_fill.odometer_km.toFixed(0)}` : '0'} style={styles.input} editable={!saving} />
        {last_fill && Number.isFinite(odoN) && odoN <= last_fill.odometer_km && <Text style={styles.hintDanger}>{t('driver.fuel.odometer_too_low')}</Text>}
        <Text style={[styles.label, { marginTop: 12 }]}>{t('driver.fuel.station')}</Text>
        <TextInput value={station} onChangeText={setStation} placeholder={t('driver.fuel.station_placeholder')} style={styles.input} editable={!saving} />
        {previewHint && previewHint.level !== 'unknown' && <VarianceHint hint={previewHint} />}
        <Pressable onPress={save} disabled={!canSave}
          style={({ pressed }) => [styles.saveBtn, !canSave && styles.saveBtnDisabled, pressed && { opacity: 0.85 }]}>
          {saving ? <ActivityIndicator color="#fff" /> : <Text style={styles.saveBtnText}>{t('driver.fuel.save')}</Text>}
        </Pressable>
      </View>
      <View style={styles.historyBox}>
        <Text style={styles.sectionTitle}>{t('driver.fuel.recent')}</Text>
        {recent_fills.length === 0 ? <Text style={styles.muted}>{t('driver.fuel.no_fills')}</Text>
          : recent_fills.map((f) => <FillRow key={f.id} fill={f} />)}
      </View>
    </ScrollView>
  );
}

function VarianceHint({ hint }: { hint: { level: string; l_per_100km: number | null; ratio: number | null } }) {
  const { t } = useI18n();
  const tone = hint.level === 'high' ? styles.hintHigh : hint.level === 'low' ? styles.hintLow : styles.hintOk;
  const label = hint.level === 'high' ? t('driver.fuel.variance_high') : hint.level === 'low' ? t('driver.fuel.variance_low') : t('driver.fuel.variance_ok');
  return (
    <View style={[styles.hintBox, tone]}>
      <Text style={[styles.hintBoxTitle, tone]}>≈ {hint.l_per_100km?.toFixed(1)} L/100km — {label}</Text>
    </View>
  );
}
function FillRow({ fill }: { fill: LocalFuelFill }) {
  const { t } = useI18n();
  const flagTone = fill.variance_flag === 'HIGH' ? styles.pillHigh : fill.variance_flag === 'LOW' ? styles.pillLow : fill.variance_flag === 'OK' ? styles.pillOk : styles.pillNeutral;
  const label = fill.variance_flag === 'HIGH' ? t('driver.fuel.variance_high') : fill.variance_flag === 'LOW' ? t('driver.fuel.variance_low') : fill.variance_flag === 'OK' ? t('driver.fuel.variance_ok') : '—';
  return (
    <View style={styles.fillRow}>
      <View style={{ flex: 1 }}>
        <Text style={styles.fillMain}>{fill.liters} L · {fill.amount_etb} ETB</Text>
        <Text style={styles.muted}>{fill.odometer_km.toFixed(0)} km · {fill.station_name}</Text>
      </View>
      <View style={{ alignItems: 'flex-end', gap: 4 }}>
        <Text style={[styles.pill, flagTone]}>{label}</Text>
        {fill.synced_at === null && <Text style={styles.pillPending}>⏳</Text>}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#fafaf7' },
  content: { padding: 16, paddingBottom: 96 },
  header: { flexDirection: 'row', alignItems: 'center', marginBottom: 12 },
  title: { fontSize: 22, fontWeight: '700', color: '#1a1a1a' },
  subtitle: { fontSize: 12, color: '#6b6b6b', marginTop: 2 },
  syncBtn: { backgroundColor: '#0f766e', paddingHorizontal: 14, paddingVertical: 10, borderRadius: 10, minWidth: 64, alignItems: 'center' },
  syncBtnText: { color: '#fff', fontWeight: '600', fontSize: 14 },
  infoBox: { backgroundColor: '#ecfdf5', borderColor: '#6ee7b7', borderWidth: 1, borderRadius: 8, padding: 10, marginBottom: 12 },
  infoText: { color: '#065f46', fontSize: 13 },
  errorBox: { backgroundColor: '#fef2f2', borderColor: '#fca5a5', borderWidth: 1, borderRadius: 8, padding: 10, marginBottom: 12 },
  errorText: { color: '#b91c1c', fontSize: 13 },
  lastFillBox: { backgroundColor: '#fff', borderWidth: 1, borderColor: '#e5e5e0', borderRadius: 10, padding: 12, marginBottom: 12 },
  card: { backgroundColor: '#fff', borderWidth: 1, borderColor: '#e5e5e0', borderRadius: 10, padding: 14, marginBottom: 16 },
  sectionTitle: { fontSize: 14, fontWeight: '600', color: '#1a1a1a', marginBottom: 8 },
  label: { fontSize: 13, color: '#1a1a1a', fontWeight: '600', marginBottom: 6 },
  input: { backgroundColor: '#fafaf7', borderWidth: 1, borderColor: '#e5e5e0', borderRadius: 8, paddingHorizontal: 12, paddingVertical: 12, fontSize: 16, color: '#1a1a1a' },
  hintDanger: { fontSize: 12, color: '#b91c1c', marginTop: 4 },
  hintBox: { borderRadius: 8, borderWidth: 1, padding: 10, marginTop: 12 },
  hintBoxTitle: { fontSize: 13, fontWeight: '600' },
  hintOk: { backgroundColor: '#f0fdf4', borderColor: '#86efac', color: '#166534' },
  hintHigh: { backgroundColor: '#fef2f2', borderColor: '#fca5a5', color: '#b91c1c' },
  hintLow: { backgroundColor: '#fffbeb', borderColor: '#fcd34d', color: '#b45309' },
  saveBtn: { backgroundColor: '#0f766e', borderRadius: 10, paddingVertical: 14, alignItems: 'center', marginTop: 16 },
  saveBtnDisabled: { backgroundColor: '#a3a3a3' },
  saveBtnText: { color: '#fff', fontSize: 15, fontWeight: '600' },
  historyBox: { backgroundColor: '#fff', borderWidth: 1, borderColor: '#e5e5e0', borderRadius: 10, padding: 14 },
  muted: { fontSize: 12, color: '#6b6b6b', marginTop: 2 },
  fillRow: { flexDirection: 'row', alignItems: 'flex-start', paddingVertical: 10, borderTopWidth: 1, borderTopColor: '#f3f3f3', gap: 8 },
  fillMain: { fontSize: 14, fontWeight: '500', color: '#1a1a1a' },
  pill: { fontSize: 11, fontWeight: '500', paddingHorizontal: 8, paddingVertical: 3, borderRadius: 6, overflow: 'hidden' },
  pillOk: { backgroundColor: '#f0fdf4', color: '#166534' },
  pillHigh: { backgroundColor: '#fef2f2', color: '#b91c1c' },
  pillLow: { backgroundColor: '#fffbeb', color: '#b45309' },
  pillNeutral: { backgroundColor: '#f3f3f3', color: '#6b6b6b' },
  pillPending: { fontSize: 12, color: '#b45309' },
});
