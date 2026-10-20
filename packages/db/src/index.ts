export class PrismaClient {
  constructor(_options?: any) {}
  $connect = async () => {};
  $disconnect = async () => {};
  $transaction = async (cb: any) => (typeof cb === 'function' ? cb(this) : cb);
  [key: string]: any;
}

export const Prisma: any = {
  Decimal: class Decimal {
    constructor(public val: any) {}
    toString() { return String(this.val); }
    toNumber() { return Number(this.val); }
  },
};

let _client: any = null;

export function db(): any {
  if (!_client) {
    const noOp: any = {
      findMany: async () => [],
      findFirst: async () => null,
      findUnique: async () => null,
      count: async () => 0,
      create: async (d: any) => ({ id: 'mock-id', ...d?.data }),
      createMany: async () => ({ count: 0 }),
      update: async (d: any) => ({ id: d?.where?.id ?? 'mock-id', ...d?.data }),
      updateMany: async () => ({ count: 0 }),
      delete: async () => ({}),
      deleteMany: async () => ({ count: 0 }),
      upsert: async (d: any) => ({ id: d?.where?.id ?? 'mock-id', ...(d?.create ?? {}) }),
    };
    _client = new Proxy(new PrismaClient(), {
      get: (target: any, prop: string) => {
        if (prop in target) return target[prop];
        return noOp;
      },
    });
  }
  return _client;
}

