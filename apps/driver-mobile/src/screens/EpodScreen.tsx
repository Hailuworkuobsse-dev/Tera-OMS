import { useState, useRef, useCallback } from 'react';
import { Modal, View, Text, ScrollView, Pressable, TextInput, ActivityIndicator, StyleSheet, Alert, KeyboardAvoidingView, Platform } from 'react-native';
import { CameraView, useCameraPermissions } from 'expo-camera';
import SignatureCanvas from 'react-native-signature-canvas';
import { useI18n } from '@tera/i18n';
import type { LocalStop, ProofOutcome, PaymentMethod } from '@tera/offline-sync';
import { recordProofOfDelivery } from '../offline/local';

interface Props { stop: LocalStop | null; outcome: ProofOutcome | null; onClose: () => void; onSaved: () => void; }

const OUTCOME_TITLE_KEY: Record<ProofOutcome, string> = {
  DELIVERED: 'driver.epod.title.delivered', PARTIAL: 'driver.epod.title.partial',
  NOT_AVAILABLE: 'driver.epod.title.not_available', RETURNED: 'driver.epod.title.returned',
};

export function EpodScreen({ stop, outcome, onClose, onSaved }: Props) {
  const { t } = useI18n();
  const [qty, setQty] = useState<string>('');
  const [reason, setReason] = useState('');
  const [signature, setSignature] = useState<string | null>(null);
  const [photo, setPhoto] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [cameraOpen, setCameraOpen] = useState(false);
  const [perm, requestPerm] = useCameraPermissions();
  const cameraRef = useRef<CameraView>(null);
  const sigRef = useRef<any>(null);
  const [paymentCollected, setPaymentCollected] = useState(true);
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>('CASH');
  const [amount, setAmount] = useState('');
  const [telebirrRef, setTelebirrRef] = useState('');

  const isOpen = stop !== null && outcome !== null;
  if (stop && qty === '' && stop.quantity_ordered > 0) setQty(String(stop.quantity_ordered));

  const requiresSignature = outcome === 'DELIVERED' || outcome === 'PARTIAL' || outcome === 'RETURNED';
  const requiresReason = outcome === 'NOT_AVAILABLE' || outcome === 'RETURNED';
  const showPaymentSection = (outcome === 'DELIVERED' || outcome === 'PARTIAL') && paymentCollected;
  const qtyNum = qty.trim() === '' ? null : parseInt(qty.trim(), 10);
  const qtyValid = qtyNum !== null && Number.isFinite(qtyNum) && qtyNum >= 0;
  const partialValid = outcome !== 'PARTIAL' || (qtyNum !== null && stop !== null && qtyNum < stop.quantity_ordered);
  const amountNum = amount.trim() === '' ? null : parseFloat(amount.trim());
  const amountValid = !showPaymentSection || (amountNum !== null && Number.isFinite(amountNum) && amountNum > 0);
  const telebirrRefValid = !showPaymentSection || paymentMethod === 'CASH' || (telebirrRef.trim().length >= 6 && /^[A-Za-z0-9_-]+$/.test(telebirrRef.trim()));
  const canSave = stop !== null && outcome !== null && qtyValid && partialValid && amountValid && telebirrRefValid
    && (!requiresSignature || signature !== null) && (!requiresReason || reason.trim().length > 0) && !saving;

  const capturePhoto = useCallback(async () => {
    if (!perm?.granted) { const r = await requestPerm(); if (!r.granted) { Alert.alert(t('driver.epod.perm_denied')); return; } }
    setCameraOpen(true);
  }, [perm, requestPerm, t]);

  const takePicture = useCallback(async () => {
    if (!cameraRef.current) return;
    try {
      const pic = await cameraRef.current.takePictureAsync({ base64: true, quality: 0.3, skipProcessing: true });
      if (pic?.base64) setPhoto(`data:image/jpeg;base64,${pic.base64}`);
      setCameraOpen(false);
    } catch (e) { Alert.alert(t('common.error'), String(e)); }
  }, [t]);

  const save = useCallback(async () => {
    if (!stop || !outcome || !canSave) return;
    setSaving(true);
    try {
      await recordProofOfDelivery({
        stopId: stop.id, outcome,
        qtyConfirmed: qtyNum ?? 0, qtyOrdered: stop.quantity_ordered,
        reason: requiresReason ? reason.trim() : null,
        signatureBase64: requiresSignature ? signature : null,
        photoBase64: photo,
        payment: showPaymentSection && amountNum !== null ? {
          method: paymentMethod, amountEtb: amountNum,
          telebirrRef: paymentMethod === 'TELEBIRR' ? telebirrRef.trim() : null,
        } : null,
      });
      onSaved();
    } catch (e) { Alert.alert(t('common.error'), e instanceof Error ? e.message : String(e)); }
    finally { setSaving(false); }
  }, [stop, outcome, canSave, qtyNum, reason, requiresReason, requiresSignature, signature, photo, showPaymentSection, amountNum, paymentMethod, telebirrRef, t, onSaved]);

  if (!isOpen) return null;
  return (
    <Modal visible animationType="slide" onRequestClose={onClose}>
      <KeyboardAvoidingView style={styles.root} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <View style={styles.header}>
          <Pressable onPress={onClose} hitSlop={12} style={styles.headerBtn}><Text style={styles.headerBtnText}>{t('common.cancel')}</Text></Pressable>
          <Text style={styles.headerTitle}>{t(OUTCOME_TITLE_KEY[outcome!])}</Text>
          <View style={styles.headerBtn} />
        </View>
        <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
          <View style={styles.stopBox}>
            <Text style={styles.stopName}>{stop!.distributor_name}</Text>
            <Text style={styles.muted}>{t('driver.epod.ordered')}: {stop!.quantity_ordered}</Text>
          </View>
          <View style={styles.section}>
            <Text style={styles.label}>{t('driver.epod.qty_confirmed')}</Text>
            <TextInput value={qty} onChangeText={setQty} keyboardType="number-pad" placeholder="0" style={styles.input} editable={!saving} />
            {!partialValid && <Text style={styles.hintDanger}>{t('driver.epod.partial_hint', { ordered: stop!.quantity_ordered })}</Text>}
          </View>
          {requiresReason && (
            <View style={styles.section}>
              <Text style={styles.label}>{t('driver.epod.reason')}</Text>
              <TextInput value={reason} onChangeText={setReason} placeholder={t('driver.epod.reason_placeholder')} multiline numberOfLines={3} style={[styles.input, styles.multiline]} editable={!saving} />
            </View>
          )}
          {requiresSignature && (
            <View style={styles.section}>
              <View style={styles.labelRow}>
                <Text style={styles.label}>{t('driver.epod.signature')}</Text>
                {signature && <Pressable onPress={() => { setSignature(null); sigRef.current?.clearSignature?.(); }}><Text style={styles.clearBtn}>{t('driver.epod.clear')}</Text></Pressable>}
              </View>
              {signature ? <View style={styles.signatureBox}><Text style={styles.signedLabel}>{t('driver.epod.signed')}</Text></View>
                : <View style={styles.signatureBox}>
                    <SignatureCanvas ref={sigRef} onOK={(s: string) => setSignature(s || null)} onEmpty={() => setSignature(null)}
                      descriptionText="" clearText={t('driver.epod.clear')} confirmText={t('driver.epod.confirm')}
                      webStyle=".m-signature-pad { box-shadow: none; border: none; }" />
                  </View>}
            </View>
          )}
          {(outcome === 'DELIVERED' || outcome === 'PARTIAL') && (
            <View style={styles.section}>
              <View style={styles.labelRow}><Text style={styles.label}>{t('driver.payment.section')}</Text></View>
              <View style={styles.toggleRow}>
                <Pressable onPress={() => setPaymentCollected(true)} style={[styles.toggleBtn, paymentCollected && styles.toggleBtnActive]}>
                  <Text style={[styles.toggleText, paymentCollected && styles.toggleTextActive]}>{t('driver.payment.collected_yes')}</Text>
                </Pressable>
                <Pressable onPress={() => setPaymentCollected(false)} style={[styles.toggleBtn, !paymentCollected && styles.toggleBtnActive]}>
                  <Text style={[styles.toggleText, !paymentCollected && styles.toggleTextActive]}>{t('driver.payment.collected_no')}</Text>
                </Pressable>
              </View>
              {paymentCollected ? (
                <>
                  <View style={styles.methodRow}>
                    <Pressable onPress={() => setPaymentMethod('CASH')} style={[styles.methodBtn, paymentMethod === 'CASH' && styles.methodBtnActive]}>
                      <Text style={[styles.methodText, paymentMethod === 'CASH' && styles.methodTextActive]}>{t('driver.payment.method_cash')}</Text>
                    </Pressable>
                    <Pressable onPress={() => setPaymentMethod('TELEBIRR')} style={[styles.methodBtn, paymentMethod === 'TELEBIRR' && styles.methodBtnActive]}>
                      <Text style={[styles.methodText, paymentMethod === 'TELEBIRR' && styles.methodTextActive]}>{t('driver.payment.method_telebirr')}</Text>
                    </Pressable>
                  </View>
                  <Text style={styles.label}>{t('driver.payment.amount')}</Text>
                  <TextInput value={amount} onChangeText={setAmount} keyboardType="decimal-pad" placeholder="0" style={styles.input} editable={!saving} />
                  {paymentMethod === 'TELEBIRR' && (
                    <>
                      <Text style={[styles.label, { marginTop: 12 }]}>{t('driver.payment.ref')}</Text>
                      <TextInput value={telebirrRef} onChangeText={setTelebirrRef} placeholder={t('driver.payment.ref_placeholder')} autoCapitalize="characters" autoCorrect={false} style={styles.input} editable={!saving} />
                      {telebirrRef.length > 0 && !telebirrRefValid && <Text style={styles.hintDanger}>{t('driver.payment.ref_invalid')}</Text>}
                    </>
                  )}
                </>
              ) : <Text style={styles.hint}>{t('driver.payment.no_payment_hint')}</Text>}
            </View>
          )}
          <View style={styles.section}>
            <View style={styles.labelRow}>
              <Text style={styles.label}>{t('driver.epod.photo')}</Text>
              {photo && <Pressable onPress={() => setPhoto(null)}><Text style={styles.clearBtn}>{t('driver.epod.clear')}</Text></Pressable>}
            </View>
            {photo ? <View style={styles.photoBox}><Text style={styles.signedLabel}>{t('driver.epod.photo_captured')}</Text></View>
              : cameraOpen ? (
                <View style={styles.cameraContainer}>
                  <CameraView ref={cameraRef} style={styles.camera} facing="back" />
                  <View style={styles.cameraActions}>
                    <Pressable onPress={() => setCameraOpen(false)} style={styles.camBtnSecondary}><Text style={[styles.camBtnText, { color: '#1a1a1a' }]}>{t('common.cancel')}</Text></Pressable>
                    <Pressable onPress={takePicture} style={styles.camBtnPrimary}><Text style={styles.camBtnText}>{t('driver.epod.capture')}</Text></Pressable>
                  </View>
                </View>
              ) : <Pressable onPress={capturePhoto} style={styles.photoBtn}><Text style={styles.photoBtnText}>{t('driver.epod.open_camera')}</Text></Pressable>}
          </View>
        </ScrollView>
        <View style={styles.footer}>
          <Pressable onPress={save} disabled={!canSave}
            style={({ pressed }) => [styles.saveBtn, !canSave && styles.saveBtnDisabled, pressed && { opacity: 0.85 }]}>
            {saving ? <ActivityIndicator color="#fff" /> : <Text style={styles.saveBtnText}>{t('driver.epod.save')}</Text>}
          </Pressable>
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#fafaf7' },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 16, paddingVertical: 14, borderBottomWidth: 1, borderBottomColor: '#e5e5e0', backgroundColor: '#fff' },
  headerBtn: { minWidth: 60 },
  headerBtnText: { color: '#0f766e', fontSize: 15, fontWeight: '500' },
  headerTitle: { fontSize: 16, fontWeight: '600', color: '#1a1a1a' },
  content: { padding: 16, paddingBottom: 100 },
  stopBox: { backgroundColor: '#fff', borderRadius: 10, padding: 12, marginBottom: 16, borderWidth: 1, borderColor: '#e5e5e0' },
  stopName: { fontSize: 17, fontWeight: '600', color: '#1a1a1a' },
  muted: { fontSize: 13, color: '#6b6b6b', marginTop: 4 },
  section: { marginBottom: 20 },
  label: { fontSize: 13, color: '#1a1a1a', fontWeight: '600', marginBottom: 6 },
  labelRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 },
  clearBtn: { fontSize: 13, color: '#b91c1c', fontWeight: '500' },
  input: { backgroundColor: '#fff', borderWidth: 1, borderColor: '#e5e5e0', borderRadius: 8, paddingHorizontal: 12, paddingVertical: 12, fontSize: 16, color: '#1a1a1a' },
  multiline: { minHeight: 72, textAlignVertical: 'top' },
  hintDanger: { fontSize: 12, color: '#b91c1c', marginTop: 4 },
  hint: { fontSize: 12, color: '#6b6b6b', marginTop: 4 },
  signatureBox: { height: 200, backgroundColor: '#fff', borderRadius: 10, borderWidth: 1, borderColor: '#e5e5e0', overflow: 'hidden', alignItems: 'center', justifyContent: 'center' },
  signedLabel: { color: '#166534', fontSize: 14, fontWeight: '500' },
  photoBox: { height: 160, backgroundColor: '#fff', borderRadius: 10, borderWidth: 1, borderColor: '#e5e5e0', alignItems: 'center', justifyContent: 'center' },
  cameraContainer: { borderRadius: 10, overflow: 'hidden', backgroundColor: '#000' },
  camera: { height: 260, width: '100%' },
  cameraActions: { flexDirection: 'row', backgroundColor: '#fff' },
  camBtnPrimary: { flex: 1, paddingVertical: 14, alignItems: 'center', backgroundColor: '#0f766e' },
  camBtnSecondary: { flex: 1, paddingVertical: 14, alignItems: 'center', backgroundColor: '#fff' },
  camBtnText: { color: '#fff', fontWeight: '600', fontSize: 15 },
  photoBtn: { backgroundColor: '#fff', borderWidth: 1, borderColor: '#0f766e', borderRadius: 10, paddingVertical: 14, alignItems: 'center' },
  photoBtnText: { color: '#0f766e', fontSize: 15, fontWeight: '600' },
  toggleRow: { flexDirection: 'row', gap: 8, marginBottom: 12 },
  toggleBtn: { flex: 1, paddingVertical: 10, borderRadius: 8, alignItems: 'center', borderWidth: 1, borderColor: '#e5e5e0', backgroundColor: '#fff' },
  toggleBtnActive: { borderColor: '#0f766e', backgroundColor: '#ecfdf5' },
  toggleText: { fontSize: 14, color: '#6b6b6b', fontWeight: '500' },
  toggleTextActive: { color: '#0f766e', fontWeight: '600' },
  methodRow: { flexDirection: 'row', gap: 8, marginBottom: 12 },
  methodBtn: { flex: 1, paddingVertical: 12, borderRadius: 8, alignItems: 'center', borderWidth: 1, borderColor: '#e5e5e0', backgroundColor: '#fff' },
  methodBtnActive: { borderColor: '#0f766e', backgroundColor: '#ecfdf5' },
  methodText: { fontSize: 14, color: '#6b6b6b', fontWeight: '500' },
  methodTextActive: { color: '#0f766e', fontWeight: '600' },
  footer: { position: 'absolute', bottom: 0, left: 0, right: 0, padding: 16, paddingBottom: 24, backgroundColor: '#fafaf7', borderTopWidth: 1, borderTopColor: '#e5e5e0' },
  saveBtn: { backgroundColor: '#0f766e', borderRadius: 10, paddingVertical: 16, alignItems: 'center' },
  saveBtnDisabled: { backgroundColor: '#a3a3a3' },
  saveBtnText: { color: '#fff', fontSize: 16, fontWeight: '600' },
});
