import fs from 'node:fs'
import decode from 'audio-decode'
import { writeFile } from 'node:fs/promises'

const input = process.argv[2], output = process.argv[3]
const audio = await decode(fs.readFileSync(input))
const channels = audio.channelData
const count = channels[0].length
const out = Buffer.alloc(44 + count * 2)
out.write('RIFF'); out.writeUInt32LE(36 + count * 2, 4); out.write('WAVE', 8)
out.write('fmt ', 12); out.writeUInt32LE(16, 16); out.writeUInt16LE(1, 20); out.writeUInt16LE(1, 22)
out.writeUInt32LE(audio.sampleRate, 24); out.writeUInt32LE(audio.sampleRate * 2, 28); out.writeUInt16LE(2, 32); out.writeUInt16LE(16, 34)
out.write('data', 36); out.writeUInt32LE(count * 2, 40)
for (let i = 0; i < count; i++) out.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(channels[0][i] * 32767))), 44 + i * 2)
await writeFile(output, out)
