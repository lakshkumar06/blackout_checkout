import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,readFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {Wallet,JsonRpcProvider} from 'ethers';
import {cancelTypes,domain,intentKey,match,receiveTypes,receiveValue,sendTypes,sendValue,verifyReceive,verifySend} from '../src/intents.mjs';
import {Matcher} from '../server/matcher.mjs';

const vendor=Wallet.createRandom(),payer=Wallet.createRandom(),contract=Wallet.createRandom().address;
async function pair(deadline=Math.floor(Date.now()/1000)+3600){
  const base={v:2,chain:5042002,contract,id:'0x00000000000000000000000000000001',vendor:vendor.address,
    amount:'1000000000000000000',deadline};
  const receive={...base,kind:'receive',signature:await vendor.signTypedData(domain(contract),receiveTypes,receiveValue(base))};
  const sendBase={...base,kind:'send',payer:payer.address};
  const send={...sendBase,signature:await payer.signTypedData(domain(contract),sendTypes,sendValue(sendBase))};
  return {receive,send};
}
test('both offline signatures bind the same exact order',async()=>{
  const {receive,send}=await pair();
  assert.ok(match(verifyReceive(receive,contract),verifySend(send,contract)));
  assert.throws(()=>verifyReceive({...receive,amount:'2'},contract),/signature/);
  assert.throws(()=>verifySend({...send,vendor:payer.address},contract),/signature/);
  assert.throws(()=>verifySend(send,Wallet.createRandom().address),/contract/);
  assert.equal(intentKey(send),vendor.address.toLowerCase()+':'+send.id);
});
test('expired offline intents never reach settlement',async()=>{
  const {receive,send}=await pair(Math.floor(Date.now()/1000)-1);
  const folder=await mkdtemp(join(tmpdir(),'blackout-expired-'));
  const provider=new JsonRpcProvider('http://127.0.0.1:1');
  const matcher=new Matcher({provider,contract,key:Wallet.createRandom().privateKey,file:join(folder,'matches.json')});
  matcher.contract={settle:async()=>{throw Error('must not settle');}};
  await matcher.load();
  assert.equal((await matcher.submit(receive)).status,'expired');
  assert.equal((await matcher.submit(send)).status,'expired');
  await matcher.process();
  assert.equal(matcher.status(intentKey(send)).status,'expired');
});
test('matcher waits for both uploads and persists a submitted Arc transaction',async()=>{
  const {receive,send}=await pair(),folder=await mkdtemp(join(tmpdir(),'blackout-matcher-'));
  const file=join(folder,'matches.json');
  const provider=new JsonRpcProvider('http://127.0.0.1:1');
  provider.getTransactionReceipt=async()=>({status:1});
  const matcher=new Matcher({provider,contract,key:Wallet.createRandom().privateKey,file});
  matcher.contract={orderKey:async()=>send.id,settled:async()=>false,balanceOf:async()=>BigInt(send.amount),
    settle:async()=>({hash:'0x'+'ab'.repeat(32)})};
  await matcher.load();
  assert.equal((await matcher.submit(receive)).status,'waiting');
  assert.equal((await matcher.submit(send)).status,'matched');
  await matcher.process();assert.equal(matcher.status(intentKey(send)).status,'submitted');
  await matcher.process();assert.equal(matcher.status(intentKey(send)).status,'settled');
  const persisted=JSON.parse(await readFile(file));assert.equal(persisted[intentKey(send)].status,'settled');
  await assert.rejects(matcher.submit({...send,amount:'2'}),/signature/);
});
test('merchant cancellation blocks later uploads but cannot cancel a buyer payment',async()=>{
  const {receive,send}=await pair(),folder=await mkdtemp(join(tmpdir(),'blackout-cancel-'));
  const file=join(folder,'matches.json'),provider=new JsonRpcProvider('http://127.0.0.1:1');
  const matcher=new Matcher({provider,contract,key:Wallet.createRandom().privateKey,file});
  await matcher.load();
  const cancel={v:2,kind:'cancel',chain:5042002,contract,id:receive.id,vendor:vendor.address,
    signature:await vendor.signTypedData(domain(contract),cancelTypes,{id:receive.id,vendor:vendor.address})};
  await matcher.submit(receive);
  assert.equal((await matcher.cancel(cancel)).status,'cancelled');
  assert.equal((await matcher.submit(send)).status,'cancelled');
  assert.equal((await matcher.submit(receive)).status,'cancelled');
  assert.equal(JSON.parse(await readFile(file))[intentKey(receive)].status,'cancelled');
  await assert.rejects(matcher.cancel({...cancel,vendor:payer.address}),/signature/);
  const second=new Matcher({provider,contract,key:Wallet.createRandom().privateKey,file:join(folder,'other.json')});
  await second.load();await second.submit(send);
  await assert.rejects(second.cancel(cancel),/Customer payment already received/);
});
