extends RefCounted
class_name WebSaveCrypto

const SCRIPT := """
if (!window.__tdVaultCrypto) {
 const te=new TextEncoder(), td=new TextDecoder();
 const b64=b=>{let s='';b.forEach(x=>s+=String.fromCharCode(x));return btoa(s).replace(/\\+/g,'-').replace(/\\//g,'_').replace(/=+$/,'')};
 const unb64=s=>{s=s.replace(/-/g,'+').replace(/_/g,'/');while(s.length%4)s+='=';return Uint8Array.from(atob(s),c=>c.charCodeAt(0))};
 const digest=async raw=>new Uint8Array(await crypto.subtle.digest('SHA-256',raw));
 const derive=async recovery=>{const packed=unb64(recovery.trim().replace(/^TD1-/,''));if(packed.length!==34)throw Error('invalid_recovery_key');const raw=packed.slice(0,32),sum=await digest(raw);if(packed[32]!==sum[0]||packed[33]!==sum[1])throw Error('invalid_recovery_key');const base=await crypto.subtle.importKey('raw',raw,'HKDF',false,['deriveBits','deriveKey']);const salt=te.encode('TinyDemons-vault-v1');const bits=async label=>new Uint8Array(await crypto.subtle.deriveBits({name:'HKDF',hash:'SHA-256',salt,info:te.encode(label)},base,256));const key=await crypto.subtle.deriveKey({name:'HKDF',hash:'SHA-256',salt,info:te.encode('encryption')},base,{name:'AES-GCM',length:256},false,['encrypt','decrypt']);return {key,vault:b64(await bits('vault-id')),proof:b64(await bits('write-proof'))}};
 const format=async raw=>{const sum=await digest(raw);return 'TD1-'+b64(new Uint8Array([...raw,sum[0],sum[1]]))};
 window.__tdVaultCrypto={
  create:async(json,cb)=>{try{const raw=crypto.getRandomValues(new Uint8Array(32)),recovery=await format(raw),d=await derive(recovery),iv=crypto.getRandomValues(new Uint8Array(12)),ct=new Uint8Array(await crypto.subtle.encrypt({name:'AES-GCM',iv},d.key,te.encode(json)));cb(JSON.stringify({ok:true,recovery,vault_id:d.vault,write_proof:d.proof,ciphertext:b64(new Uint8Array([...iv,...ct]))}))}catch(e){cb(JSON.stringify({ok:false,error:String(e.message||e)}))}},
  encrypt:async(recovery,json,cb)=>{try{const d=await derive(recovery),iv=crypto.getRandomValues(new Uint8Array(12)),ct=new Uint8Array(await crypto.subtle.encrypt({name:'AES-GCM',iv},d.key,te.encode(json)));cb(JSON.stringify({ok:true,vault_id:d.vault,write_proof:d.proof,ciphertext:b64(new Uint8Array([...iv,...ct]))}))}catch(e){cb(JSON.stringify({ok:false,error:String(e.message||e)}))}},
  decrypt:async(recovery,payload,cb)=>{try{const d=await derive(recovery),all=unb64(payload),plain=await crypto.subtle.decrypt({name:'AES-GCM',iv:all.slice(0,12)},d.key,all.slice(12));cb(JSON.stringify({ok:true,vault_id:d.vault,write_proof:d.proof,plaintext:td.decode(plain)}))}catch(e){cb(JSON.stringify({ok:false,error:'invalid_key_or_backup'}))}}
 };
}
"""

static func available() -> bool:
	return OS.has_feature("web")

static func install() -> void:
	if available(): JavaScriptBridge.eval(SCRIPT)
