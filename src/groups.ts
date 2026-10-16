import lists from './checklists.json';
import { Phase } from './types';
const definitions = {
 pre: [
  { title: 'Preparation & Safety', indexes: [0,1,2,7,10] },
  { title: 'Cabin & Deck', indexes: [4,8,9,11,12,20,21,22] },
  { title: 'Engine & Instruments', indexes: [5,6,13,14,15,16,17,3,18,19] },
 ],
 post: [
  { title: 'Final Log & Position', indexes: [0,1,10] },
  { title: 'Engine & Power', indexes: [2,3,8] },
  { title: 'Cabin & Deck', indexes: [4,5,6,7,9] },
 ],
};
export const groups = (phase: Phase) => definitions[phase].map(g=>({title:g.title,items:g.indexes.map(i=>lists[phase][i])}));
