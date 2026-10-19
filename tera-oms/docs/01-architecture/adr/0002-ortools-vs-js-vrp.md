# ADR 0002 — VRP solver choice

Pilot (< 500 stops): `@applied.math.coding/vehicle-routing-problem` (pure TS).
Scale: swap to OR-Tools (Python sidecar) if solver time or constraint complexity
exceeds pure-JS capability. The Routing module's `solver/` folder is the only
place that changes.
