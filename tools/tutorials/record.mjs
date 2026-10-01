// node record.mjs <video> [<video> ...]   - records videos/<video>.mjs from the running demo stack (README.md)
import { recordWeb } from './lib.mjs';

for (const name of process.argv.slice(2)) {
  const v = (await import(`./videos/${name}.mjs`)).default;
  console.log(`● ${v.name}`);
  await recordWeb({ name: v.name, viewport: v.viewport, mobile: v.mobile, script: v.script });
}
