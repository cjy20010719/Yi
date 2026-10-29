// Public verification only: never reads a signing private key.
const { readFileSync } = require('node:fs');
const { createPublicKey, verify } = require('node:crypto');
const [publicKey, signature, archive] = process.argv.slice(2);
const rawKey = Buffer.from(publicKey, 'base64');
const rawSignature = Buffer.from(signature, 'base64');
if (rawKey.length !== 32 || rawSignature.length !== 64) throw new Error('Invalid key or signature length');
const key = createPublicKey({key: Buffer.concat([Buffer.from('302a300506032b6570032100','hex'),rawKey]),format:'der',type:'spki'});
if (!verify(null, readFileSync(archive), key, rawSignature)) throw new Error('EdDSA verification failed');
console.log('PASS: archive signature matches the public key embedded in Yi');
