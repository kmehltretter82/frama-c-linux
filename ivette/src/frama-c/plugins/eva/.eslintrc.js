module.exports = {
  root: true,
  overrides: [
    {
      files: ['*.js', '*.jsx', '*.ts', '*.tsx'],
      excludedFiles: 'Summary.tsx|Coverage.tsx|CoverageMeter.tsx',
      extends: ["../../../../.eslintrc.js"]
    },
    {
      files: ['Summary.tsx','Coverage.tsx'],
      extends: [
        'eslint:recommended',
        'plugin:react/recommended',
        'plugin:react-hooks/recommended',
        'plugin:@typescript-eslint/eslint-recommended',
        'plugin:@typescript-eslint/recommended',
      ],
      rules: {
        "@typescript-eslint/explicit-function-return-type": [
          "error",
          { allowExpressions: true }
        ]
      }
    }
  ]
};
