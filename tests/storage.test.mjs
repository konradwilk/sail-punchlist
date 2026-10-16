import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import ts from 'typescript';
import { initialState } from '../src/model.mjs';
async function storage() {
 const files=new Map();let fail=false;
 const fs={documentDirectory:'docs/',cacheDirectory:'cache/',getInfoAsync:async p=>({exists:files.has(p)}),readAsStringAsync:async p=>{if(!files.has(p))throw Error('missing');return files.get(p);},writeAsStringAsync:async(p,v)=>{await new Promise(r=>setTimeout(r,2));if(fail){fail=false;throw Error('disk full');}files.set(p,v);},copyAsync:async({from,to})=>{if(!files.has(from))throw Error('missing');files.set(to,files.get(from));},moveAsync:async({from,to})=>{files.set(to,files.get(from));files.delete(from);}};
 const key='__storageTest'+Math.random().toString(36).slice(2);globalThis[key]=fs;
 let source=await readFile(new URL('../src/storage.ts',import.meta.url),'utf8');
 source=source.replace("import * as FS from 'expo-file-system/legacy';",`const FS=globalThis.${key};`).replace("'./model.mjs'",JSON.stringify(new URL('../src/model.mjs',import.meta.url).href));
 const output=ts.transpileModule(source,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ESNext}}).outputText;
 const api=await import('data:text/javascript;base64,'+Buffer.from(output).toString('base64'));
 return {api,files,failNext:()=>{fail=true;}};
}
test('serialized writes retain newest draft and export a JSON snapshot',async()=>{const {api,files}=await storage();const first=initialState(),last=initialState();last.drafts.pre.hours='231';await Promise.all([api.save(first),api.save(last)]);assert.equal((await api.load()).state.drafts.pre.hours,'231');assert.equal(JSON.parse(files.get('docs/sail-punchlist.backup.json')).drafts.pre.hours,'');const path=await api.exportFile();assert.equal(JSON.parse(files.get(path)).drafts.pre.hours,'231');});
test('write failure does not destroy main file and a later retry succeeds',async()=>{const {api,files,failNext}=await storage();await api.save(initialState());const before=files.get(api.filePath);failNext();await assert.rejects(api.save({...initialState(),phase:'post'}),/disk full/);assert.equal(files.get(api.filePath),before);await api.save({...initialState(),phase:'post'});assert.equal((await api.load()).state.phase,'post');});
test('corrupt main recovers backup, preserves evidence, and retains valid backup',async()=>{const {api,files}=await storage();await api.save(initialState());await api.save({...initialState(),phase:'post'});files.set(api.filePath,'broken JSON');const result=await api.load();assert.equal(result.recovered,true);assert.equal(result.state.phase,'pre');assert.ok([...files.keys()].some(k=>k.includes('.unreadable-')));await api.save(result.state);assert.equal(JSON.parse(files.get('docs/sail-punchlist.backup.json')).version,2);});
test('corrupt data without a backup fails closed',async()=>{const {api,files}=await storage();files.set(api.filePath,'{}');await assert.rejects(api.load(),/Original files are preserved/);assert.equal(files.get(api.filePath),'{}');});
test('interrupted replacement with no main file restores pending snapshot',async()=>{const {api,files}=await storage();const pending={...initialState(),phase:'post'};files.set(api.filePath+'.tmp',JSON.stringify(pending));const result=await api.load();assert.equal(result.recovered,true);assert.equal(result.state.phase,'post');});
