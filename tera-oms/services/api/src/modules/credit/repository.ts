import { db } from '@tera/db';

export function findAccounts() {
  return db().creditAccount.findMany({
    include: {
      distributor: { select: { id: true, name: true, region: true } },
      overrides: { where: { expiresAt: { gt: new Date() } } },
    },
    orderBy: { createdAt: 'asc' },
  });
}

export function findAllAccountsForFinance() {
  return db().creditAccount.findMany({
    include: { distributor: { select: { name: true, region: true } } },
    orderBy: { updatedAt: 'desc' },
  });
}

export function findAllOverrides(limit: number) {
  return db().creditOverride.findMany({ orderBy: { createdAt: 'desc' }, take: limit });
}

export function findDistributorsByIds(ids: string[]) {
  return db().distributor.findMany({
    where: { id: { in: ids } },
    select: { id: true, name: true },
  });
}

export function recordDecision(input: {
  accountId: string; outcome: string; reason: string;
  exposureEtb: number; limitEtb: number; daysOverdue: number;
}) {
  return db().creditDecision.create({ data: input });
}

export function createOverride(input: {
  decisionId?: string; distributorId: string;
  reason: string; actorId: string; expiresAt: Date;
}) {
  return db().creditOverride.create({ data: input });
}
