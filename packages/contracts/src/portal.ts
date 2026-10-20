import { z } from 'zod';

export const PortalProfileSchema = z.object({
  distributor_id: z.string(), name: z.string(), region: z.string(),
  credit_limit_etb: z.number(), exposure_etb: z.number(),
  headroom_etb: z.number(), utilization_pct: z.number(),
});

export const CatalogItemSchema = z.object({
  sku_id: z.string(), code: z.string(), name: z.string(), unit: z.string(),
  weight_kg: z.number(), volume_m3: z.number(),
  unit_price_etb: z.number(), stock_on_hand: z.number().int(),
});
export const CatalogResponseSchema = z.object({ items: z.array(CatalogItemSchema) });

export const PlaceOrderLineSchema = z.object({
  sku_id: z.string().min(1), quantity: z.number().int().positive(),
});
export const PlaceOrderRequestSchema = z.object({
  lines: z.array(PlaceOrderLineSchema).min(1).max(50),
  note: z.string().max(500).optional(),
});
export const PlaceOrderResponseSchema = z.object({
  order_id: z.string(), status: z.string(),
  total_etb: z.number(), total_quantity: z.number().int(),
  eta: z.string().nullable(),
});

export const OrderStatusEnum = z.enum(['PENDING', 'ROUTED', 'DELIVERED', 'FAILED']);
export const PortalOrderSummarySchema = z.object({
  order_id: z.string(), status: OrderStatusEnum,
  created_at: z.string().datetime(),
  total_etb: z.number(), total_quantity: z.number().int(),
  line_count: z.number().int(), eta: z.string().nullable(),
  vehicle_id: z.string().nullable(), last_stop_status: z.string().nullable(),
});
export const PortalOrdersResponseSchema = z.object({
  active: z.array(PortalOrderSummarySchema), recent: z.array(PortalOrderSummarySchema),
});
export const PortalOrderDetailSchema = PortalOrderSummarySchema.extend({
  driver_id: z.string().nullable(), route_stop_id: z.string().nullable(),
  lines: z.array(z.object({
    sku_id: z.string(), sku_code: z.string(), sku_name: z.string(),
    quantity: z.number().int(), unit_price_etb: z.number(), line_total_etb: z.number(),
  })),
});

export const StatementPaymentRowSchema = z.object({
  id: z.string(), method: z.enum(['CASH', 'TELEBIRR']),
  amount_etb: z.number(), captured_at: z.string().datetime(), reconciled: z.boolean(),
});
export const StatementDeliveryRowSchema = z.object({
  order_id: z.string(), delivered_at: z.string().datetime(),
  total_quantity: z.number().int(), vehicle_id: z.string(),
});
export const StatementResponseSchema = z.object({
  as_of: z.string().datetime(), balance_etb: z.number(), limit_etb: z.number(),
  grace_days: z.number().int(),
  days_since_oldest_unpaid: z.number().int().nullable(),
  recent_payments: z.array(StatementPaymentRowSchema),
  recent_deliveries: z.array(StatementDeliveryRowSchema),
});

export const DisputeTypeEnum = z.enum(['QUANTITY', 'WRONG_ITEM', 'NEVER_DELIVERED', 'DAMAGED', 'OTHER']);
export const RaiseDisputeRequestSchema = z.object({
  order_id: z.string().min(1), type: DisputeTypeEnum,
  description: z.string().trim().min(10).max(1000),
});
export const DisputeRowSchema = z.object({
  id: z.string(), order_id: z.string(), type: DisputeTypeEnum,
  description: z.string(),
  status: z.enum(['OPEN', 'UNDER_REVIEW', 'RESOLVED', 'REJECTED']),
  created_at: z.string().datetime(), resolution_notes: z.string().nullable(),
});
export const DisputesListResponseSchema = z.object({ disputes: z.array(DisputeRowSchema) });

export type PortalProfile = z.infer<typeof PortalProfileSchema>;
export type CatalogItem = z.infer<typeof CatalogItemSchema>;
export type PlaceOrderRequest = z.infer<typeof PlaceOrderRequestSchema>;
export type PlaceOrderResponse = z.infer<typeof PlaceOrderResponseSchema>;
export type PortalOrderSummary = z.infer<typeof PortalOrderSummarySchema>;
export type PortalOrdersResponse = z.infer<typeof PortalOrdersResponseSchema>;
export type PortalOrderDetail = z.infer<typeof PortalOrderDetailSchema>;
export type StatementResponse = z.infer<typeof StatementResponseSchema>;
export type DisputeRow = z.infer<typeof DisputeRowSchema>;
export type RaiseDisputeRequest = z.infer<typeof RaiseDisputeRequestSchema>;
