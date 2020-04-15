module.exports = {
  root: true,
  parser: '@typescript-eslint/parser',
  plugins: [
    '@typescript-eslint',
  ],
  extends: [
    'eslint:recommended',
    'plugin:react/recommended',
    'plugin:react-hooks/recommended',
    'plugin:@typescript-eslint/eslint-recommended',
    'plugin:@typescript-eslint/recommended',
  ],
  rules: {
    "react/display-name": 'off',
    // Allow type any, even if it should be avoided
    "@typescript-eslint/no-explicit-any": "off",
    // Allow functions without return type, even if exported function should have one
    "@typescript-eslint/explicit-function-return-type": "off",
    // Allow function hoisting, even if it should be avoided
    "no-use-before-define": [
      "error",
      { functions: false, classes: true, variables: true },
    ],
    "@typescript-eslint/no-use-before-define": [
      "error",
      { functions: false, classes: true, variables: true, typedefs: true },
    ],
    // Prefer const when _all_ destructured values may be const
    "prefer-const": [
      "error",
      { "destructuring": "all", "ignoreReadBeforeAssign": false }
    ],
  }
};