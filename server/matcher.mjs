import {mkdir,readFile,rename,writeFile} from 'node:fs/promises';
import {dirname} from 'node:path';
import {Contract,Wallet} from 'ethers';
import {escrowAbi,intentKey,match,verifyCancel,verifyReceive,verifySend} from '../src/intents.mjs';

export class Matcher {
  constructor({provider,contract,key,file='runtime/matches.json'}){
    this.provider=provider;
    this.contractAddress=contract;
    this.file=file;
    this.contract=new Contract(contract,escrowAbi,new Wallet(key,provider));
    this.entries={};
    this.serial=Promise.resolve();
  }
  async load(){
    try{this.entries=JSON.parse(await readFile(this.file,'utf8'));}
    catch(error){if(error.code!=='ENOENT')throw error;}
  }
  queue(fn){
    const result=this.serial.then(fn);
    this.serial=result.catch(()=>{});
    return result;
  }
  async persist(){
    await mkdir(dirname(this.file),{recursive:true});
    const temp=this.file+'.tmp';
    await writeFile(temp,JSON.stringify(this.entries),{mode:0o600});
    await rename(temp,this.file);
  }
  async submit(raw){
    const intent=raw?.kind==='receive'?verifyReceive(raw,this.contractAddress):verifySend(raw,this.contractAddress);
    return this.queue(async()=>{
      const key=intentKey(intent),entry=this.entries[key]||{status:'waiting',updated:Date.now()};
      if(entry.status==='cancelled')return this.status(key);
      if(!this.entries[key]&&Object.keys(this.entries).length>=10000)throw Error('Matcher queue full');
      const old=entry[intent.kind];
      if(old&&JSON.stringify(old)!==JSON.stringify(intent))throw Error('Conflicting intent for this order');
      const other=entry[intent.kind==='receive'?'send':'receive'];
      if(other&&!match(intent,other))throw Error('Send and receive terms differ');
      entry[intent.kind]=intent;
      entry.updated=Date.now();
      if(Math.floor(Date.now()/1000)>intent.deadline){entry.status='expired';entry.error='Intent expired before upload';}
      else if(entry.receive&&entry.send&&entry.status==='waiting')entry.status='matched';
      this.entries[key]=entry;
      await this.persist();
      return this.status(key);
    });
  }
  async cancel(raw){
    const cancellation=verifyCancel(raw,this.contractAddress);
    return this.queue(async()=>{
      const key=intentKey(cancellation),entry=this.entries[key]||{updated:Date.now()};
      if(!this.entries[key]&&Object.keys(this.entries).length>=10000)throw Error('Matcher queue full');
      if(entry.send||entry.txHash||['matched','submitted','settled','external_settlement'].includes(entry.status))
        throw Error('Customer payment already received; this invoice cannot be cancelled');
      entry.status='cancelled';entry.error=null;entry.updated=Date.now();
      this.entries[key]=entry;await this.persist();
      return this.status(key);
    });
  }
  status(key){
    const entry=this.entries[key];
    if(!entry)return {status:'unknown'};
    return {status:entry.status,txHash:entry.txHash||null,error:entry.error||null,updated:entry.updated};
  }
  async process(){
    return this.queue(async()=>{
      for(const [key,entry] of Object.entries(this.entries)){
        if(!entry.receive||!entry.send||entry.status==='settled'||entry.status==='expired'||entry.status==='cancelled'||entry.status==='external_settlement')continue;
        const o=entry.send;
        if(entry.txHash){
          try{
            const receipt=await this.provider.getTransactionReceipt(entry.txHash);
            if(!receipt)continue;
            entry.status=receipt.status===1?'settled':'failed';
            entry.error=receipt.status===1?null:'Settlement transaction failed';
          }catch(error){entry.error=error.shortMessage||error.message;}
        }else if(Math.floor(Date.now()/1000)>o.deadline){
          entry.status='expired';entry.error='Intent expired before settlement';
        }else{
          try{
            const onChain=await this.contract.settled(await this.contract.orderKey(o.vendor,o.id));
            if(onChain){entry.status='external_settlement';entry.error='Order already settled outside this matcher';}
            else if((await this.contract.balanceOf(o.payer))<BigInt(o.amount)){
              entry.status='awaiting_funds';entry.error='Customer escrow balance is too low';
            }else{
              const tx=await this.contract.settle(
                [o.id,o.vendor,o.payer,o.amount,o.deadline],entry.receive.signature,entry.send.signature);
              entry.txHash=tx.hash;entry.status='submitted';entry.error=null;
            }
          }catch(error){entry.status='retrying';entry.error=error.shortMessage||error.message;}
        }
        entry.updated=Date.now();
        await this.persist();
      }
    });
  }
}
