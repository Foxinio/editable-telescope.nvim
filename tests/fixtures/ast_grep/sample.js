// TODO: sample comment
import { thing } from './thing';
const fs = require('fs');

export class Widget {
  draw() { console.log("a string", `template ${thing}`); }
}

export function helper(a) {
  if (a == null) debugger;
  return JSON.parse(a);
}

const arrow = async (a) => {
  const r = await fetch(a);
  r.then((x) => x);
  setTimeout(() => {}, 1);
  document.addEventListener('click', helper);
  const [s, setS] = useState(0);
  for (const k in a) {}
  try { helper(a); } catch (e) {}
};
