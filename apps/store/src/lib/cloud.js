import {supabase,isCloudReady} from './supabase';
export async function signIn(email,password){if(!isCloudReady)throw new Error('Cloud is not configured. Copy .env.example to .env and add Supabase keys.'); const {data,error}=await supabase.auth.signInWithPassword({email,password}); if(error)throw error; return data.session}
export async function signOut(){if(isCloudReady)await supabase.auth.signOut()}
export async function getSession(){if(!isCloudReady)return null;const {data}=await supabase.auth.getSession();return data.session}
export function subscribe(onChange){if(!isCloudReady)return ()=>{};const channel=supabase.channel('kolor-activ-erp').on('postgres_changes',{event:'*',schema:'public',table:'erp_records'},()=>onChange()).subscribe();return()=>supabase.removeChannel(channel)}
export async function cloudLoad(appId){if(!isCloudReady)return null;const {data,error}=await supabase.from('erp_records').select('payload').eq('app_id',appId).maybeSingle();if(error)throw error;return data?.payload||null}
export async function cloudSave(appId,payload){if(!isCloudReady)return;const {data:{user}}=await supabase.auth.getUser();if(!user)throw new Error('Please sign in first.');const {error}=await supabase.from('erp_records').upsert({app_id:appId,payload,updated_by:user.id,updated_at:new Date().toISOString()},{onConflict:'app_id'});if(error)throw error}
