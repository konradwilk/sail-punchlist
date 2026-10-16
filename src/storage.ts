// SPDX-License-Identifier: BSD-3-Clause
import * as FS from 'expo-file-system/legacy';
import { initialState, resume } from './model.mjs';
import { State } from './types';
export const filePath = FS.documentDirectory + 'sail-punchlist.json';
const backup = FS.documentDirectory + 'sail-punchlist.backup.json';
function parse(text: string): State {
 const data = JSON.parse(text);
 if (data.version !== 2 || !['pre','post'].includes(data.phase) || !data.drafts?.pre?.answers || !data.drafts?.post?.answers || !Array.isArray(data.records)) throw Error('Unrecognized data file.');
 for (const phase of ['pre','post']) {
  const draft=data.drafts[phase];
  if(typeof draft.hours!=='string' || typeof draft.answers!=='object' || Array.isArray(draft.answers) || !(draft.fuel===null || (Number.isFinite(draft.fuel) && draft.fuel>=0 && draft.fuel<=100))) throw Error('Invalid draft data.');
  for(const answer of Object.values(draft.answers) as any[]) if(!answer || !['done','issue'].includes(answer.status) || typeof answer.note!=='string') throw Error('Invalid item response.');
 }
 if(data.identity!==null && (!data.identity || typeof data.identity.email!=='string' || !['apple','google'].includes(data.identity.provider))) throw Error('Invalid account data.');
 if(data.lastHours!==null && (!Number.isFinite(data.lastHours) || data.lastHours<0)) throw Error('Invalid engine reading.');
 for(const record of data.records) if(!record || typeof record.completedAt!=='string' || !Number.isFinite(Date.parse(record.completedAt)) || !['pre','post'].includes(record.phase) || !Number.isFinite(record.engineHours) || !Number.isFinite(record.fuelPercent) || typeof record.email!=='string' || !Array.isArray(record.checklist) || record.checklist.some((item:any)=>!item || typeof item.label!=='string' || !['done','issue'].includes(item.status) || typeof item.note!=='string')) throw Error('Invalid history data.');
 return resume(data) as State;
}
export async function load(): Promise<{state:State; recovered:boolean}> {
 if (!(await FS.getInfoAsync(filePath)).exists) {
  // A shutdown during file replacement can leave only the backup or temp file.
  let found=false;
  for (const candidate of [filePath+'.tmp', backup]) {
   if ((await FS.getInfoAsync(candidate)).exists) {
    found=true;
    try { return {state:parse(await FS.readAsStringAsync(candidate)),recovered:true}; }
    catch { /* Try the previous valid backup before failing closed. */ }
   }
  }
  if(found) throw Error('Interrupted save contains unreadable data. Original files are preserved.');
  return {state:initialState() as State,recovered:false};
 }
 try { return {state:parse(await FS.readAsStringAsync(filePath)),recovered:false}; }
 catch {
  // Preserve the original before any subsequent write, including when using the backup.
  const copy = filePath + '.unreadable-' + Date.now();
  await FS.copyAsync({from:filePath,to:copy});
  try { return {state:parse(await FS.readAsStringAsync(backup)),recovered:true}; }
  catch { throw Error('Could not read local records or their backup. Original files are preserved. Export them from the device Files app before repairing the installation.'); }
 }
}
let queue: Promise<void> = Promise.resolve();
export function save(state: State): Promise<void> {
 const text=JSON.stringify(state,null,2);
 const operation=queue.then(async()=>{
  const temp=filePath+'.tmp';
  await FS.writeAsStringAsync(temp,text);
  if ((await FS.getInfoAsync(filePath)).exists) {
   let valid=false;
   try { parse(await FS.readAsStringAsync(filePath)); valid=true; } catch { /* Keep the last readable backup. */ }
   if(valid) await FS.copyAsync({from:filePath,to:backup});
  }
  await FS.moveAsync({from:temp,to:filePath});
 });
 queue=operation.catch(()=>{});
 return operation;
}
export async function exportFile() {
 await queue;
 const target=FS.cacheDirectory+'sail-punchlist-export.json';
 await FS.copyAsync({from:filePath,to:target});
 return target;
}
