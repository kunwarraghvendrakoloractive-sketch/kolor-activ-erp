import { supabase } from './supabase';

const mapPM=(x:any)=>({id:x.id,code:x.code,name:x.name,shadeName:x.shade_name,shadeCode:x.shade_code,uom:x.uom,stock:Number(x.stock||0),min:Number(x.min_stock||0),max:Number(x.max_stock||0),loc:x.location||'-'});
const mapFG=(x:any)=>({id:x.id,code:x.code,name:x.name,shadeName:x.shade_name,shadeCode:x.shade_code,uom:x.uom,batch:x.batch,qty:Number(x.qty||0),mfg:x.mfg_date,expiry:x.expiry_date,loc:x.location||'-'});
const mapTx=(x:any)=>({id:x.id,docNo:x.doc_no,date:x.txn_date,type:x.txn_type,module:x.module,code:x.code,name:x.name,batch:x.batch,qtyIn:Number(x.qty_in||0),qtyOut:Number(x.qty_out||0),department:x.department,status:x.status,remarks:x.remarks});
const mapLog=(x:any)=>({id:x.id,date:x.log_date,line:x.line,shift:x.shift,product:x.product,batch:x.batch,qty:Number(x.good_qty||0),rejected:Number(x.rejected_qty||0),worker:x.worker,status:x.status});
const mapAudit=(x:any)=>({id:x.id,date:x.audit_date,module:x.module,item:x.item,batch:x.batch,system:Number(x.system_qty||0),physical:Number(x.physical_qty||0),var:Number(x.variance||0),remarks:x.remarks,status:x.status});

export async function loadNormalized(base:any){
 if(!supabase) return null;
 const [pm,fg,tx,logs,audits]=await Promise.all([
  supabase.from('pm_items').select('*').order('name'),
  supabase.from('fg_items').select('*').order('name'),
  supabase.from('stock_transactions').select('*').order('created_at',{ascending:false}).limit(5000),
  supabase.from('production_logs').select('*').order('created_at',{ascending:false}).limit(5000),
  supabase.from('stock_audits').select('*').order('audit_date',{ascending:false}).limit(5000)
 ]);
 for(const r of [pm,fg,tx,logs,audits]) if(r.error) throw r.error;
 return {...base,pm:pm.data.map(mapPM),fg:fg.data.map(mapFG),tx:tx.data.map(mapTx),logs:logs.data.map(mapLog),audits:audits.data.map(mapAudit)};
}

export async function saveNormalized(db:any, userId?:string, role='viewer'){
 if(!supabase||!userId) throw new Error('Cloud session required.');
 const pmRows=db.pm.map((x:any)=>({id:x.id,code:x.code||null,name:x.name,shade_name:x.shadeName||null,shade_code:x.shadeCode||null,uom:x.uom||'PCS',stock:x.stock||0,min_stock:x.min||0,max_stock:x.max||0,location:x.loc||null,created_by:userId,updated_at:new Date().toISOString()}));
 const fgRows=db.fg.map((x:any)=>({id:x.id,code:x.code||null,name:x.name,shade_name:x.shadeName||null,shade_code:x.shadeCode||null,uom:x.uom||'PCS',batch:x.batch,qty:x.qty||0,mfg_date:x.mfg||null,expiry_date:x.expiry||null,location:x.loc||null,created_by:userId,updated_at:new Date().toISOString()}));
 const txRows=db.tx.map((x:any)=>({id:x.id,doc_no:x.docNo||null,txn_date:x.date||new Date().toISOString().slice(0,10),txn_type:x.type||'OTHER',module:x.module||'General',code:x.code||null,name:x.name||null,batch:x.batch||null,qty_in:x.qtyIn||0,qty_out:x.qtyOut||0,department:x.department||null,status:x.status||'approved',remarks:x.remarks||null,created_by:userId}));
 const logRows=db.logs.map((x:any)=>({id:x.id,log_date:x.date||new Date().toISOString().slice(0,10),line:x.line||'Other',shift:x.shift||null,product:x.product||null,batch:x.batch||null,good_qty:x.qty||0,rejected_qty:x.rejected||0,worker:x.worker||null,status:x.status||'approved',created_by:userId}));
 const auditRows=db.audits.map((x:any)=>({id:x.id,audit_date:x.date||new Date().toISOString(),module:x.module,item:x.item,batch:x.batch||null,system_qty:x.system||0,physical_qty:x.physical||0,remarks:x.remarks||null,created_by:userId,status:x.status||'approved'}));
 const allowed:any={
  pm_items:['super_admin','ho_admin','store_manager'],
  fg_items:['super_admin','ho_admin','store_manager'],
  stock_transactions:['super_admin','ho_admin','store_manager','production_manager','employee'],
  production_logs:['super_admin','ho_admin','production_manager','employee'],
  stock_audits:['super_admin','ho_admin','store_manager']
 };
 for(const [table,rows] of [['pm_items',pmRows],['fg_items',fgRows],['stock_transactions',txRows],['production_logs',logRows],['stock_audits',auditRows]] as any){
   if(!rows.length || !allowed[table]?.includes(role)) continue;
   const {error}=await supabase.from(table).upsert(rows,{onConflict:'id'}); if(error) throw error;
 }
 if(['super_admin','ho_admin','production_manager','store_manager'].includes(role)) await createBackup(db,userId);
}

export async function createBackup(db:any,userId:string){
 if(!supabase) return;
 const key='kolor_activ_last_backup'; const last=localStorage.getItem(key); const now=Date.now();
 if(last && now-Number(last)<24*60*60*1000) return;
 const {error}=await supabase.from('backup_snapshots').insert({created_by:userId,payload:db});
 if(!error) localStorage.setItem(key,String(now));
}

export function realtime(onChange:()=>void){
 if(!supabase) return ()=>{};
 const channel=supabase.channel('kolor-activ-relational')
 .on('postgres_changes',{event:'*',schema:'public',table:'pm_items'},onChange)
 .on('postgres_changes',{event:'*',schema:'public',table:'fg_items'},onChange)
 .on('postgres_changes',{event:'*',schema:'public',table:'stock_transactions'},onChange)
 .on('postgres_changes',{event:'*',schema:'public',table:'production_logs'},onChange)
 .on('postgres_changes',{event:'*',schema:'public',table:'stock_audits'},onChange)
 .on('postgres_changes',{event:'*',schema:'public',table:'approvals'},onChange)
 .subscribe();
 return ()=>supabase.removeChannel(channel);
}

export async function getProfile(){
 if(!supabase) return null;
 const {data:{user}}=await supabase.auth.getUser(); if(!user)return null;
 const {data,error}=await supabase.from('profiles').select('*').eq('id',user.id).single(); if(error)throw error; return data;
}
export async function listApprovals(){if(!supabase)return[];const {data,error}=await supabase.from('approvals').select('*').order('requested_at',{ascending:false});if(error)throw error;return data||[]}
export async function decideApproval(id:string,status:'approved'|'rejected',remarks=''){if(!supabase)throw new Error('Cloud not configured');const {data:{user}}=await supabase.auth.getUser();if(!user)throw new Error('Sign in required');const {error}=await supabase.from('approvals').update({status,decided_by:user.id,decided_at:new Date().toISOString(),remarks}).eq('id',id);if(error)throw error}
export async function audit(action:string,entityType:string,entityId:string,oldData:any=null,newData:any=null){if(!supabase)return;await supabase.rpc('write_audit',{p_action:action,p_entity_type:entityType,p_entity_id:entityId,p_old:oldData,p_new:newData});}
export async function listAuditLogs(){if(!supabase)return[];const {data,error}=await supabase.from('audit_logs').select('*').order('created_at',{ascending:false}).limit(1000);if(error)throw error;return data||[]}
export async function uploadAttachment(file:File,entityType:string,entityId:string){if(!supabase)throw new Error('Cloud not configured');const {data:{user}}=await supabase.auth.getUser();if(!user)throw new Error('Sign in required');const safe=file.name.replace(/[^a-zA-Z0-9._-]/g,'_');const path=`${entityType}/${entityId}/${Date.now()}-${safe}`;const up=await supabase.storage.from('erp-attachments').upload(path,file,{upsert:false,contentType:file.type});if(up.error)throw up.error;const ins=await supabase.from('attachments').insert({entity_type:entityType,entity_id:entityId,file_name:file.name,storage_path:path,mime_type:file.type,size_bytes:file.size,uploaded_by:user.id}).select().single();if(ins.error)throw ins.error;return ins.data}
export async function signedAttachmentUrl(path:string){if(!supabase) return null;const {data,error}=await supabase.storage.from('erp-attachments').createSignedUrl(path,3600);if(error)throw error;return data.signedUrl}
