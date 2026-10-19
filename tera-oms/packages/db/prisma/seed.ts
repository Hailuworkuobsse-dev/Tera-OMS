import { PrismaClient } from '../generated/client';

const prisma = new PrismaClient();

async function main() {
  console.log('seed: no-op — add master data once models exist');
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
