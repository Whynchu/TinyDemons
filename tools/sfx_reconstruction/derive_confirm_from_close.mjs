import fs from 'node:fs'
const input = process.argv[2], output = process.argv[3]
const b = fs.readFileSync(input), rate = b.readUInt32LE(24), data = b.indexOf(Buffer.from('data')) + 8
const n = Math.floor((b.length - data) / 2), src = new Float32Array(n)
for (let i = 0; i < n; i++) src[i] = b.readInt16LE(data + i * 2) / 32768
const outN = Math.max(1, Math.floor(n * 0.92)), out = new Float32Array(outN)
for (let i = 0; i < outN; i++) {
  const t = i / rate, u = i / outN, env = Math.pow(Math.sin(Math.PI * u), 0.55)
  const f = 420 + 980 * u
  const transient = Math.exp(-t * 75) * Math.sin(2 * Math.PI * 1800 * t)
  out[i] = (0.62 * Math.sin(2 * Math.PI * f * t) + 0.24 * Math.sin(2 * Math.PI * f * 2.01 * t) + 0.14 * transient) * env
}
const w = Buffer.alloc(44 + outN * 2); w.write('RIFF'); w.writeUInt32LE(36 + outN * 2, 4); w.write('WAVE', 8); w.write('fmt ', 12); w.writeUInt32LE(16, 16); w.writeUInt16LE(1, 20); w.writeUInt16LE(1, 22); w.writeUInt32LE(rate, 24); w.writeUInt32LE(rate * 2, 28); w.writeUInt16LE(2, 32); w.writeUInt16LE(16, 34); w.write('data', 36); w.writeUInt32LE(outN * 2, 40)
for (let i = 0; i < outN; i++) w.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(out[i] * 30000))), 44 + i * 2)
fs.writeFileSync(output, w)
