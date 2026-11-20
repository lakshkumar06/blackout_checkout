const opening=new Promise((resolve,reject)=>{
  const request=indexedDB.open('blackout-checkout',1);
  request.onupgradeneeded=()=>{for(const name of ['orders','settings'])request.result.createObjectStore(name);};
  request.onerror=()=>reject(request.error);request.onsuccess=()=>resolve(request.result);
});
export async function get(store,key){
  const db=await opening;
  return new Promise((resolve,reject)=>{const r=db.transaction(store).objectStore(store).get(key);
    r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});
}
export async function save(store,key,value){
  const db=await opening;
  return new Promise((resolve,reject)=>{const t=db.transaction(store,'readwrite');t.objectStore(store).put(value,key);
    t.oncomplete=resolve;t.onerror=()=>reject(t.error);});
}
export async function remove(store,key){
  const db=await opening;
  return new Promise((resolve,reject)=>{const t=db.transaction(store,'readwrite');t.objectStore(store).delete(key);
    t.oncomplete=resolve;t.onerror=()=>reject(t.error);});
}
export async function allOrders(){
  const db=await opening;
  return new Promise((resolve,reject)=>{const r=db.transaction('orders').objectStore('orders').getAll();
    r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});
}
