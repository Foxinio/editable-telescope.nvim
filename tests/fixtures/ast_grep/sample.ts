// TODO: sample comment
// @ts-ignore
import { thing } from './thing';

interface Shape { area(): number }
type Id = string;
enum Kind { A, B }

@sealed
class Widget {
  draw(value: any): void { console.log("a string", value!); }
}

function helper(a: number): number {
  const conf = { a } satisfies object;
  for (let i = 0; i < a; i++) {}
  try { return a as any; } catch (e) { return 0; }
}
