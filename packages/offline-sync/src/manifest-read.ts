import type { SqliteAdapter } from './types.js';

export type PaymentStatus = 'NONE' | 'PENDING' | 'CONFIRMED';
export type PaymentMethodValue = 'CASH' | 'TELEBIRR';

export interface LocalStop {
  id: string; seq: number;
  distributor_id: string; distributor_name: string;
  lat: number; lng: number;
  planned_eta: string;
  status: 'PENDING' | 'ARRIVED' | 'DELIVERED' | 'FAILED';
  status_updated_at: string;
  quantity_ordered: number;
  payment_status: PaymentStatus;
  payment_method: PaymentMethodValue | null;
  payment_amount_etb: number | null;
}
export interface LocalPlan {
  id: string; vehicle_id: string; status: string;
  planned_km: number; planned_min: number;
  start_lat: number; start_lng: number;
}
export interface LocalManifest {
  plan: LocalPlan | null;
  stops: LocalStop[];
  counts: { total: number; pending: number; delivered: number; failed: number; paid: number; unpaid: number; };
}

interface RawStopRow {
  id: string; seq: number; distributor_id: string; distributor_name: string;
  lat: number; lng: number; planned_eta: string; status: string; status_updated_at: string;
  quantity_ordered: number;
  payment_id: string | null; payment_method: string | null;
  payment_amount_etb: number | null; payment_synced_at: string | null;
  payment_result_json: string | null;
}

export async function getLocalManifest(adapter: SqliteAdapter): Promise<LocalManifest> {
  const planRow = await adapter.get<LocalPlan>(
    `SELECT id, vehicle_id, status, planned_km, planned_min, start_lat, start_lng FROM route_plan LIMIT 1`,
  );
  const rows = await adapter.all<RawStopRow>(
    `SELECT s.id, s.seq, s.distributor_id, s.distributor_name, s.lat, s.lng,
            s.planned_eta, s.status, s.status_updated_at, s.quantity_ordered,
            p.id AS payment_id, p.method AS payment_method, p.amount_etb AS payment_amount_etb,
            o.synced_at AS payment_synced_at, o.result_json AS payment_result_json
     FROM route_stop s
     LEFT JOIN payment p ON p.stop_id = s.id
     LEFT JOIN outbox o ON o.client_op_id = p.client_op_id
     ORDER BY s.seq ASC`,
  );
  const stops: LocalStop[] = rows.map((r) => {
    let paymentStatus: PaymentStatus = 'NONE';
    if (r.payment_id) {
      if (!r.payment_synced_at) paymentStatus = 'PENDING';
      else {
        let rejected = false;
        if (r.payment_result_json) {
          try { rejected = JSON.parse(r.payment_result_json).status === 'rejected'; } catch { /* ignore */ }
        }
        paymentStatus = rejected ? 'PENDING' : 'CONFIRMED';
      }
    }
    return {
      id: r.id, seq: r.seq,
      distributor_id: r.distributor_id, distributor_name: r.distributor_name,
      lat: r.lat, lng: r.lng, planned_eta: r.planned_eta,
      status: r.status as LocalStop['status'],
      status_updated_at: r.status_updated_at,
      quantity_ordered: r.quantity_ordered,
      payment_status: paymentStatus,
      payment_method: (r.payment_method as PaymentMethodValue | null) ?? null,
      payment_amount_etb: r.payment_amount_etb,
    };
  });
  const counts = {
    total: stops.length,
    pending: stops.filter((s) => s.status === 'PENDING').length,
    delivered: stops.filter((s) => s.status === 'DELIVERED').length,
    failed: stops.filter((s) => s.status === 'FAILED').length,
    paid: stops.filter((s) => s.payment_status === 'CONFIRMED').length,
    unpaid: stops.filter((s) => s.status === 'DELIVERED' && s.payment_status !== 'CONFIRMED').length,
  };
  return { plan: planRow, stops, counts };
}
