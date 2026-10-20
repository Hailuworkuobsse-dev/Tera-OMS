import { z } from 'zod';

export const OrderSchema = z.object({
  id: z.string(), distributor_id: z.string(), distributor_name: z.string(),
  lat: z.number(), lng: z.number(), weight_kg: z.number(), volume_m3: z.number(),
  priority: z.number().int(),
  time_window_start: z.string().datetime(), time_window_end: z.string().datetime(),
  status: z.enum(['PENDING', 'ROUTED', 'DELIVERED']),
  created_at: z.string().datetime(),
});

export const PendingOrdersResponseSchema = z.object({ orders: z.array(OrderSchema) });
export type Order = z.infer<typeof OrderSchema>;
