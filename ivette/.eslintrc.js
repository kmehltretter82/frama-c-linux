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
  settings: {
    // Electron is in devDependencies because of its special build system
    "import/core-modules": [ "electron" ]
  },
  rules: {
    "react/display-name": "off",
    // Be more strict on usage of useMemo and useRef
    "react-hooks/exhaustive-deps": "error",
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
    // Forbid shadowing concerning variables
    "no-shadow": "error",
    // Force single class member per line
    "lines-between-class-members": [
      "error", "always", { "exceptAfterSingleLine": true }
    ],
    // Allow blank line separators for complex blocks
    "padded-blocks": "off",
    // Allow braces on their own line
    "@typescript-eslint/brace-style": "off",
    // Already has built-in compiler checks in TSC for that
    "@typescript-eslint/no-unused-vars": "off",
    // Allow range conditions such as 0 <= x && x < 10
    "yoda": [2, "never", { "onlyEquality": true }],
    // Allow single command on new line after 'if' statement
    "curly": "off",
    // Do not specify position for single commands
    "nonblock-statement-body-position": "off",
    // Allow ++/-- operators only in for-loops
    "no-plusplus": ["error", { "allowForLoopAfterthoughts": true }],
    // Force code to 80 columns, but for trailing comments
    "max-len": ["error", { "code": 80, "ignoreTrailingComments": true, }],
    // Allow more than one class per file, even if not a good practice
    "max-classes-per-file": "off",
    // Allow assignment in return statements only with outer parenthesis
    "no-return-assign": ["error", "except-parens" ],
    // Allow single line expressions in react
    "react/jsx-one-expression-per-line": "off",
    // Allow property spreading since with aim at using TSC
    "react/jsx-props-no-spreading": "off",
    // Allow all sorts of linebreaking for operators
    "operator-linebreak": "off",
    // Force curly brackets on newline if some item is
    "object-curly-newline": ["error", { "multiline": true }],
    // Allow non-destructed assignments
    "react/destructuring-assignment": "off",
    // Allow console errors and warnings
    "no-console": ["error", { allow: ["warn", "error"] }],
    // Disable accessibility rules
    "jsx-a11y/label-has-associated-control": "off",
    "jsx-a11y/click-events-have-key-events": "off",
    "jsx-a11y/no-static-element-interactions": "off",
    "jsx-a11y/no-noninteractive-element-interactions": "off",
    "jsx-a11y/no-autofocus": "off",
    // Completely broken rule
    "react/prop-types": "off",
    // Enable ++ and --
    "no-plusplus": "off",
    // Enable nested ternary operations
    "no-nested-ternary": "off",
    // Checked by TSC compiler
    "default-case": "off",
    "consistent-return": "off",
    // Allow modify properties of object passed in parameter
    "no-param-reassign": [ "error", { "props": false } ],
    // Disallow the use of var in favor of let and const
    "no-var": "error",
    // Do not favor default import
    "import/prefer-default-export": "off",
  }
};
