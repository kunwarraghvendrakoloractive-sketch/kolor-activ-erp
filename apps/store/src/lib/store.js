const KEY='kolor_activ_react_v1';
const legacyStore='kolorActivStoreV2';
const legacyProd='kolor_activ_erp_v27';
const base={
  pm:[{id:'pm-1',code:'PM-001',name:'Lipstick Outer Box',shadeName:'Red',shadeCode:'R01',uom:'PCS',stock:5000,min:1000,max:10000,loc:'PM-R01'}],
  fg:[{id:'fg-m-1',code:'KA-LIP-001',name:'Blush Babe Lipstick',shadeName:'1',shadeCode:'1',uom:'PCS',batch:'MASTER',qty:0,loc:'FG-A01'}],
  tx:[], audits:[], logs:[], users:[], seq:{receipt:0,issue:0,transfer:0}, settings:{company:'Hevlon Cosmetics Pvt. Ltd.',brand:'Kolor Activ'}
};
const clone=x=>JSON.parse(JSON.stringify(x));
export function loadLocal(){
  try{const modern=JSON.parse(localStorage.getItem(KEY)); if(modern)return {...clone(base),...modern};}catch{}
  try{const s=JSON.parse(localStorage.getItem(legacyStore)); if(s)return {...clone(base),pm:s.pm||base.pm,fg:s.fg||base.fg,tx:s.tx||[],audits:s.audits||[]};}catch{}
  try{const p=JSON.parse(localStorage.getItem(legacyProd)); if(p)return {...clone(base),logs:p.logs||[],settings:{...base.settings,...p.branding}};}catch{}
  return clone(base);
}
export function saveLocal(db){localStorage.setItem(KEY,JSON.stringify(db));}
export function uid(prefix='id'){return `${prefix}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2,7)}`}
export function today(){return new Date().toISOString().slice(0,10)}
export function docNo(prefix,db,key){const n=(db.seq[key]||0)+1;db.seq[key]=n;return `${prefix}-${today().replaceAll('-','')}-${String(n).padStart(3,'0')}`}
