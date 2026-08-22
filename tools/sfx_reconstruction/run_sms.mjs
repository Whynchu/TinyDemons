import fs from 'node:fs'
import sms from '@audio/stretch-sms'

function readWav(path) {
  const b = fs.readFileSync(path)
  if (b.toString('ascii', 0, 4) !== 'RIFF') throw new Error('expected RIFF WAV')
  const channels = b.readUInt16LE(22), rate = b.readUInt32LE(24), bits = b.readUInt16LE(34)
  const data = b.indexOf(Buffer.from('data')) + 8
  const count = Math.floor((b.length - data) / (bits / 8) / channels)
  const out = new Float32Array(count)
  for (let i = 0; i < count; i++) out[i] = b.readInt16LE(data + i * channels * 2) / 32768
  return { rate, samples: out }
}
function writeWav(path, samples, rate) {
  const b = Buffer.alloc(44 + samples.length * 2)
  b.write('RIFF', 0); b.writeUInt32LE(36 + samples.length * 2, 4); b.write('WAVE', 8)
  b.write('fmt ', 12); b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20); b.writeUInt16LE(1, 22)
  b.writeUInt32LE(rate, 24); b.writeUInt32LE(rate * 2, 28); b.writeUInt16LE(2, 32); b.writeUInt16LE(16, 34)
  b.write('data', 36); b.writeUInt32LE(samples.length * 2, 40)
  for (let i = 0; i < samples.length; i++) b.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(samples[i] * 32767))), 44 + i * 2)
  fs.writeFileSync(path, b)
}
const input = readWav(process.argv[2])
// 1.000001 forces the package through analysis/synthesis; factor === 1 is an
// intentional fast path that returns the input unchanged.
const output = sms(input.samples, { factor: 1.000001, frameSize: 4096, hopSize: 512, maxTracks: 120, residualMix: 1 })
writeWav(process.argv[3], output, input.rate)
