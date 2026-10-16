// SPDX-License-Identifier: BSD-3-Clause
import checklists from './checklists.json' with { type: 'json' };
export const emptyDraft = (hours = '') => ({ answers: {}, fuel: null, hours: String(hours) });
export const initialState = () => ({ version: 2, identity: null, phase: 'pre', lastHours: null, drafts: { pre: emptyDraft(), post: emptyDraft() }, records: [] });
export function complete(state, now = new Date()) {
 const draft = state.drafts[state.phase];
 if (!state.identity?.email) throw Error('Sign in from Account before saving a checklist.');
 if (!checklists[state.phase].every(item => ['done', 'issue'].includes(draft.answers[item.id]?.status))) throw Error('Mark each item with ✓ Done or ✕ Issue.');
 if (draft.fuel === null || !Number.isFinite(draft.fuel) || draft.fuel < 0 || draft.fuel > 100) throw Error('Select the fuel level.');
 const hours = Number(draft.hours);
 if (!draft.hours.trim() || !Number.isFinite(hours) || hours < 0) throw Error('Enter valid engine hours.');
 if (state.lastHours !== null && hours < state.lastHours) throw Error('Engine hours cannot be below the last recorded reading.');
 const timestamp = now.toISOString();
 const record = { id: `${timestamp}-${state.records.length}`, phase: state.phase, completedAt: timestamp, timezone: Intl.DateTimeFormat().resolvedOptions().timeZone, email: state.identity.email, provider: state.identity.provider, fuelPercent: draft.fuel, engineHours: hours, checklist: checklists[state.phase].map(item => ({ ...item, status: draft.answers[item.id].status, note: draft.answers[item.id].status === 'issue' ? draft.answers[item.id].note : '' })) };
 const next = state.phase === 'pre' ? 'post' : 'pre';
 return { ...state, phase: next, lastHours: hours, drafts: { ...state.drafts, [state.phase]: emptyDraft(hours + 1), [next]: { ...state.drafts[next], hours: String(hours + 1) } }, records: [...state.records, record] };
}
export function resume(state) {
 const hours = state.lastHours === null ? '' : String(state.lastHours + 1);
 return { ...state, drafts: Object.fromEntries(Object.entries(state.drafts).map(([phase,draft])=>[phase,{...draft,hours:draft.hours || hours}])) };
}
