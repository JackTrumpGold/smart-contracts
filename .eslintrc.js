module.exports = {
  env: {
    browser: false,
    es2021: true,
    mocha: true,
    node: true,
  },
  plugins: ["@typescript-eslint"],
  extends: [
    "standard",
    "plugin:prettier/recommended",
    "plugin:node/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    ecmaVersion: 12,
  },
  settings: {
    node: {
      allowModules: ["./0_utils"],
      resolvePaths: [__dirname],
      tryExtensions: [".js", ".json", ".node"],
    },
  },
  rules: {
    "node/no-missing-import": "warning",
    "node/no-unsupported-features/es-syntax": [
      "error",
      { ignores: ["modules"] },
    ],
  },
};
