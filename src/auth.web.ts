import { Identity } from './types';
export async function signIn(): Promise<Identity|null> { throw Error('Apple and Google sign-in are available in the native iOS and Android builds.'); }
export async function signOut() {}
