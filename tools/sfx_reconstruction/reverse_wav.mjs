import fs from 'node:fs'

const input = process.argv[2]
const output = process.argv[3]
const b = fs.readFileSync(input)
if (b.toString('ascii', 0, 4) !== 'RIFF') throw new Error('expected RIFF WAV')
const channels = b.readUInt16LE(22)
const bits = b.readUInt16LE(34)
const dataStart = b.indexOf(Buffer.from('data')) + 8
const bytesPerSample = bits / 8
const frameBytes = channels * bytesPerSample
const frameCount = Math.floor((b.length - dataStart) / frameBytes)
const out = Buffer.from(b)
for (let i = 0; i < frameCount; i++) {
  const src = dataStart + (frameCount - 1 - i) * frameBytes
  const dst = dataStart + i * frameBytes
  b.copy(out, dst, src, src + frameBytes)
}
fs.writeFileSync(output, out)
