// Consumes `route.solve_requested` jobs from BullMQ.
// Returns a route plan or a specific infeasibility reason (never a silent bad plan).
console.log('optimizer ready');
