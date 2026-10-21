// Reproduction helper. Expo CLI evaluates the app config on every manifest
// request, so sleeping here makes the dev server slow to answer the manifest —
// standing in for what makes it slow in real projects (the per-request
// `runtimeversion:resolve` under the fingerprint policy, a tunnel, a busy
// machine). REPRO_DELAY_MS unset: no delay.
const delayMs = Number(process.env.REPRO_DELAY_MS || 0);

module.exports = ({ config }) => {
  if (delayMs > 0) {
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, delayMs);
  }
  return config;
};
