import { initialState } from './model.mjs';
import { State } from './types';
export async function load(): Promise<{state:State;recovered:boolean}> {
 const text=localStorage.getItem('sail-punchlist');
 if(!text)return {state:initialState() as State,recovered:false};
 const state=JSON.parse(text);
 if(state.version!==2)throw Error('Unrecognized browser data. Original data preserved.');
 return {state,recovered:false};
}
export async function save(state:State){localStorage.setItem('sail-punchlist',JSON.stringify(state));}
export async function exportFile(){
 const text=localStorage.getItem('sail-punchlist')||'{}';
 const url=URL.createObjectURL(new Blob([text],{type:'application/json'}));
 const a=document.createElement('a');a.href=url;a.download='sail-punchlist.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);return '';
}
