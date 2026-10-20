import { useEffect, useState } from 'react';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { I18nProvider, useI18n } from '@tera/i18n';
import { ManifestScreen } from './src/screens/ManifestScreen';
import { FuelLogScreen } from './src/screens/FuelLogScreen';
import { SyncDemoScreen } from './src/screens/SyncDemoScreen';
import { getEngine } from './src/offline/engine';

type Tab = 'manifest' | 'fuel' | 'sync';

function Shell() {
  const { t } = useI18n();
  const [ready, setReady] = useState(false);
  const [tab, setTab] = useState<Tab>('manifest');
  useEffect(() => {
    (async () => { try { await getEngine(); } catch (e) { console.error('engine init', e); } finally { setReady(true); } })();
  }, []);
  if (!ready) return null;
  return (
    <View style={styles.root}>
      <View style={styles.screen}>
        {tab === 'manifest' ? <ManifestScreen /> : tab === 'fuel' ? <FuelLogScreen /> : <SyncDemoScreen />}
      </View>
      <View style={styles.tabBar}>
        <TabBtn label={t('driver.tab.manifest')} active={tab === 'manifest'} onPress={() => setTab('manifest')} />
        <TabBtn label={t('driver.tab.fuel')} active={tab === 'fuel'} onPress={() => setTab('fuel')} />
        <TabBtn label={t('driver.tab.sync')} active={tab === 'sync'} onPress={() => setTab('sync')} />
      </View>
    </View>
  );
}
function TabBtn({ label, active, onPress }: { label: string; active: boolean; onPress: () => void }) {
  return (
    <Pressable onPress={onPress} style={styles.tabBtn}>
      <Text style={[styles.tabText, active && styles.tabTextActive]}>{label}</Text>
      {active && <View style={styles.tabUnderline} />}
    </Pressable>
  );
}
export default function App() {
  return (
    <SafeAreaProvider>
      <I18nProvider initialLocale="am">
        <StatusBar style="dark" />
        <SafeAreaView style={{ flex: 1 }} edges={['top', 'bottom']}><Shell /></SafeAreaView>
      </I18nProvider>
    </SafeAreaProvider>
  );
}
const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#fafaf7' },
  screen: { flex: 1 },
  tabBar: { flexDirection: 'row', borderTopWidth: 1, borderTopColor: '#e5e5e0', backgroundColor: '#fff', paddingTop: 8 },
  tabBtn: { flex: 1, alignItems: 'center', paddingVertical: 8 },
  tabText: { fontSize: 13, color: '#6b6b6b', fontWeight: '500' },
  tabTextActive: { color: '#0f766e', fontWeight: '700' },
  tabUnderline: { width: 24, height: 2, backgroundColor: '#0f766e', borderRadius: 2, marginTop: 4 },
});
