module.exports = {
  forbidden: [
    {
      name: 'no-cross-module-repository',
      severity: 'error',
      from: { path: '^services/api/src/modules/([^/]+)/' },
      to: {
        path: '^services/api/src/modules/([^/]+)/repository\\.ts$',
        pathNot: '^services/api/src/modules/$1/repository\\.ts$',
      },
    },
    {
      name: 'core-cannot-import-modules',
      severity: 'error',
      from: { path: '^services/api/src/(core|shared)/' },
      to: { path: '^services/api/src/modules/' },
    },
  ],
  options: {
    doNotFollow: { path: 'node_modules' },
    tsPreCompilationDeps: true,
    tsConfig: { fileName: 'services/api/tsconfig.json' },
  },
};
