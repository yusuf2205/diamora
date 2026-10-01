// node record-app.mjs <video> - records videos/<video>.mjs on the running emulator (README.md)
import { recordApp } from './mlib.mjs';

for (const name of process.argv.slice(2)) {
  const v = (await import(`./videos/${name}.mjs`)).default;
  console.log(`● ${v.name}`);
  await recordApp({ name: v.name, script: v.script, setup: v.setup });
}
