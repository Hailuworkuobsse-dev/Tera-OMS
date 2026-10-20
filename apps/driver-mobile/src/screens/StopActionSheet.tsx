import { Modal, View, Text, Pressable, StyleSheet } from 'react-native';
import { useI18n } from '@tera/i18n';
import type { LocalStop, StopAction, ProofOutcome } from '@tera/offline-sync';

export type SheetChoice = { kind: 'status'; action: StopAction } | { kind: 'proof'; outcome: ProofOutcome };
interface Props { stop: LocalStop | null; onChoose: (c: SheetChoice) => void; onCancel: () => void; }

const CHOICES = [
  { id: 'arrived',     choice: { kind: 'status' as const, action: 'ARRIVED' as const },  labelKey: 'driver.manifest.action.arrived',     color: '#b45309', bg: '#fffbeb' },
  { id: 'delivered',   choice: { kind: 'proof' as const, outcome: 'DELIVERED' as const }, labelKey: 'driver.manifest.action.delivered',  color: '#166534', bg: '#f0fdf4' },
  { id: 'partial',     choice: { kind: 'proof' as const, outcome: 'PARTIAL' as const },   labelKey: 'driver.manifest.action.partial',    color: '#0f766e', bg: '#ecfdf5' },
  { id: 'not_available', choice: { kind: 'proof' as const, outcome: 'NOT_AVAILABLE' as const }, labelKey: 'driver.manifest.action.not_available', color: '#b91c1c', bg: '#fef2f2' },
];

export function StopActionSheet({ stop, onChoose, onCancel }: Props) {
  const { t } = useI18n();
  return (
    <Modal visible={stop !== null} transparent animationType="slide" onRequestClose={onCancel}>
      <Pressable style={styles.backdrop} onPress={onCancel}>
        <Pressable style={styles.sheet} onPress={() => {}}>
          {stop && (
            <>
              <View style={styles.header}>
                <Text style={styles.seq}>#{stop.seq}</Text>
                <View style={{ flex: 1 }}>
                  <Text style={styles.name}>{stop.distributor_name}</Text>
                  <Text style={styles.muted}>{t('time.eta')} {new Date(stop.planned_eta).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })} · {t('driver.epod.ordered')}: {stop.quantity_ordered}</Text>
                </View>
              </View>
              {CHOICES.map((c) => (
                <Pressable key={c.id} onPress={() => onChoose(c.choice)}
                  style={({ pressed }) => [styles.actionBtn, { backgroundColor: c.bg }, pressed && { opacity: 0.7 }]}>
                  <Text style={[styles.actionText, { color: c.color }]}>{t(c.labelKey)}</Text>
                </Pressable>
              ))}
              <Pressable onPress={onCancel} style={({ pressed }) => [styles.cancelBtn, pressed && { opacity: 0.6 }]}>
                <Text style={styles.cancelText}>{t('common.cancel')}</Text>
              </Pressable>
            </>
          )}
        </Pressable>
      </Pressable>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.4)', justifyContent: 'flex-end' },
  sheet: { backgroundColor: '#fff', borderTopLeftRadius: 20, borderTopRightRadius: 20, padding: 20, paddingBottom: 36 },
  header: { flexDirection: 'row', alignItems: 'center', marginBottom: 16 },
  seq: { width: 32, height: 32, textAlign: 'center', lineHeight: 32, borderRadius: 16, backgroundColor: '#f3f3f3', fontWeight: '700', fontSize: 13, marginRight: 12, color: '#1a1a1a' },
  name: { fontSize: 17, fontWeight: '600', color: '#1a1a1a' },
  muted: { fontSize: 13, color: '#6b6b6b', marginTop: 2 },
  actionBtn: { paddingVertical: 16, borderRadius: 12, alignItems: 'center', marginBottom: 8 },
  actionText: { fontSize: 16, fontWeight: '600' },
  cancelBtn: { paddingVertical: 14, alignItems: 'center', marginTop: 4 },
  cancelText: { fontSize: 15, color: '#6b6b6b', fontWeight: '500' },
});
