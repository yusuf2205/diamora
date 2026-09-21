module.exports = async () => {
  if (globalThis.__TEST_PG__) await globalThis.__TEST_PG__.stop().catch(() => {});
};
