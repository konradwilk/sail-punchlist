export type Phase = 'pre' | 'post';
export type Answer = { status: 'done' | 'issue'; note: string };
export type Draft = { answers: Record<string, Answer>; fuel: number | null; hours: string };
export type Identity = { provider: 'apple' | 'google'; id: string; email: string };
export type SailRecord = { id: string; phase: Phase; completedAt: string; timezone: string; email: string; provider: string; fuelPercent: number; engineHours: number; checklist: { id: string; label: string; status: 'done' | 'issue'; note: string }[] };
export type State = { version: 2; identity: Identity | null; phase: Phase; lastHours: number | null; drafts: Record<Phase, Draft>; records: SailRecord[] };
