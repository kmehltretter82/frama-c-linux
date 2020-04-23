module.exports = {
  root: true,
  parser: '@typescript-eslint/parser',
  plugins: [
    '@typescript-eslint',
  ],
  extends: [
    'airbnb-typescript',
    'eslint:recommended',
    'plugin:react/recommended',
    'plugin:react-hooks/recommended',
    'plugin:@typescript-eslint/eslint-recommended',
    'plugin:@typescript-eslint/recommended',
  ],
  parserOptions: {
    project: './tsconfig.json',
  },
  rules: {
    "react/display-name": "off",
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
    // Allow declarations with char '_' as prefix/suffix
    "no-underscore-dangle": "off",
    // Allow return statements even if not strictly needed
    "no-useless-return": "off",
    // Just warn about shadowing concerning variables
    "no-shadow": "warn",
    "lines-between-class-members": [
      "error", "always", { "exceptAfterSingleLine": true }
    ],
    // Allow ++/-- operators only in for-loops
    "no-plusplus": ["error", { "allowForLoopAfterthoughts": true }],
    // Just warn about simple promise rejections
    "prefer-promise-reject-errors": "warn",
    // Force code to 80 columns, but for trailing comments
    "max-len": ["error", { "code": 80, "ignoreTrailingComments": true, }],
    // Allow more than one class per file, even if not a good practice
    "max-classes-per-file": "off",
    // Allow assignment in return statements only with outer parenthesis
    "no-return-assign": ["error", "except-parens" ],
    // Allow single line expressions in react
    "react/jsx-one-expression-per-line": "off",
    // Allow all sorts of linebreaking for operators
    "operator-linebreak": "off",
    // Force curly brackets on newline if some item is
    "object-curly-newline": ["error", { "multiline": true }],
    // Allow non-destructed assignments
    "react/destructuring-assignment": "off",
    // Allow console errors and warnings
    "no-console": ["error", { allow: ["warn", "error"] }],
  }
};