module.exports = {
  root: true,
  overrides: [
    {
      files: ['*.js', '*.jsx', '*.ts', '*.tsx'],
      excludedFiles: 'Summary.tsx',
      extends: ["../../../../.eslintrc.js"]
    },
    {
      files: ['Summary.tsx'],
      extends: [
        'eslint:recommended',
        'plugin:react/recommended',
        'plugin:react-hooks/recommended',
        'plugin:@typescript-eslint/eslint-recommended',
        'plugin:@typescript-eslint/recommended',
      ]
    }
  ]
};
