import { Platform } from 'react-native';
import * as Apple from 'expo-apple-authentication';
import * as SecureStore from 'expo-secure-store';
import { Identity } from './types';
export async function signIn(): Promise<Identity | null> {
 if (Platform.OS === 'ios') {
  if (!await Apple.isAvailableAsync()) throw Error('Apple sign-in is unavailable on this device.');
  try {
   const credential = await Apple.signInAsync({ requestedScopes: [Apple.AppleAuthenticationScope.EMAIL] });
   const key = 'apple-email-' + credential.user;
   const email = credential.email || await SecureStore.getItemAsync(key);
   if (!email) throw Error('Apple did not return an email. Revoke Sail Punchlist under Sign in with Apple in Settings, then sign in again to share your email.');
   await SecureStore.setItemAsync(key, email);
   return { provider: 'apple', id: credential.user, email };
  } catch (error: any) { if(error.code==='ERR_REQUEST_CANCELED')return null; throw error; }
 }
 if (Platform.OS === 'android') {
  const clientId=process.env.EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID;
  if (!clientId) throw Error('Google sign-in needs EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID. See README.md for Android OAuth setup.');
  const { GoogleSignin, isSuccessResponse, statusCodes } = await import('@react-native-google-signin/google-signin');
  GoogleSignin.configure({ webClientId: clientId });
  try {
   await GoogleSignin.hasPlayServices({showPlayServicesUpdateDialog:true});
   const response = await GoogleSignin.signIn();
   if (!isSuccessResponse(response)) return null;
   return { provider:'google', id:response.data.user.id, email:response.data.user.email };
  } catch (error:any) { if(error.code===statusCodes.SIGN_IN_CANCELLED)return null; throw error; }
 }
 throw Error('Use the iOS or Android app for account sign-in.');
}
export async function signOut() {
 if(Platform.OS==='android') {
  const {GoogleSignin}=await import('@react-native-google-signin/google-signin');
  if(process.env.EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID){GoogleSignin.configure({webClientId:process.env.EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID});await GoogleSignin.signOut();}
 }
}
