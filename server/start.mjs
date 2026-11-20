import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {Contract,getAddress,JsonRpcProvider,keccak256,TypedDataEncoder} from 'ethers';
import {Matcher} from './matcher.mjs';
import {CHAIN,domain,escrowAbi,intentKey} from '../src/intents.mjs';

const port=Number(process.env.PORT||4173);
const host=process.env.HOST||'0.0.0.0';
const contract=getAddress(process.env.CHECKOUT_ADDRESS);
const key=process.env.MATCHER_PRIVATE_KEY_FILE
  ? (await readFile(process.env.MATCHER_PRIVATE_KEY_FILE,'utf8')).trim()
  : process.env.MATCHER_PRIVATE_KEY;
if(!key)throw Error('Set MATCHER_PRIVATE_KEY or MATCHER_PRIVATE_KEY_FILE for the funded Arc Testnet matcher wallet');
const provider=new JsonRpcProvider(process.env.ARC_RPC||'https://rpc.testnet.arc.io',undefined,{batchMaxCount:1});
if((await provider.getNetwork()).chainId!==BigInt(CHAIN))throw Error('Use Arc Testnet RPC');
const {runtime,immutableReferences}=JSON.parse(await readFile('artifacts/contract.json'));
function maskImmutables(code){
  const bytes=code.slice(2).match(/../g);
  for(const refs of Object.values(immutableReferences))for(const {start,length} of refs)
    for(let i=start;i<start+length;i++)bytes[i]='00';
  return '0x'+bytes.join('');
}
const actual=await provider.getCode(contract);
if(actual.length!==runtime.length||keccak256(maskImmutables(actual))!==keccak256(maskImmutables(runtime)))
  throw Error('Checkout address has unexpected bytecode');
const escrow=new Contract(contract,escrowAbi,provider);
if(await escrow.DOMAIN_SEPARATOR()!==TypedDataEncoder.hashDomain(domain(contract)))
  throw Error('Checkout signature domain does not match this chain');
const matcher=new Matcher({provider,contract,key,
  file:process.env.MATCHER_STATE_FILE||'runtime/matches.json'});
await matcher.load();
matcher.process().catch(console.error);
setInterval(()=>matcher.process().catch(console.error),10000).unref();
const assets={'/':['index.html','text/html'],'/app.js':['app.js','text/javascript'],
  '/sw.js':['sw.js','text/javascript'],'/style.css':['style.css','text/css']};
function json(res,status,value){res.writeHead(status,{'content-type':'application/json','cache-control':'no-store'});res.end(JSON.stringify(value));}
function sameOrigin(req){
  // Native clients do not send Origin. Browser requests do, so keep the
  // same-origin check for them while accepting signed intents from iOS.
  if(!req.headers.origin)return true;
  try{return new URL(req.headers.origin).host===req.headers.host;}catch{return false;}
}
async function body(req){
  if(!req.headers['content-type']?.startsWith('application/json'))throw Error('Use application/json');
  const chunks=[];let size=0;
  for await(const chunk of req){size+=chunk.length;if(size>4096)throw Error('Intent too large');chunks.push(chunk);}
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}
createServer(async(req,res)=>{
  try{
    const path=new URL(req.url,'http://localhost').pathname;
    if(path==='/api/config'&&req.method==='GET')return json(res,200,{chain:CHAIN,contract,
      rpc:process.env.PUBLIC_ARC_RPC||'https://rpc.testnet.arc.io',mode:'delayed-escrow'});
    if(path==='/api/intents'&&req.method==='POST'){
      if(!sameOrigin(req))return json(res,403,{error:'Same origin required'});
      const result=await matcher.submit(await body(req));
      matcher.process().catch(console.error);
      return json(res,200,result);
    }
    if(path==='/api/cancel'&&req.method==='POST'){
      if(!sameOrigin(req))return json(res,403,{error:'Same origin required'});
      return json(res,200,await matcher.cancel(await body(req)));
    }
    const status=/^\/api\/status\/(0x[\da-fA-F]{40})\/(0x[\da-fA-F]{32})$/.exec(path);
    if(status&&req.method==='GET')return json(res,200,matcher.status(intentKey({vendor:getAddress(status[1]),id:status[2].toLowerCase()})));
    const balance=/^\/api\/balance\/(0x[\da-fA-F]{40})$/.exec(path);
    if(balance&&req.method==='GET')return json(res,200,{balance:String(await escrow.balanceOf(getAddress(balance[1])))});
    const walletBalance=/^\/api\/wallet-balance\/(0x[\da-fA-F]{40})$/.exec(path);
    if(walletBalance&&req.method==='GET')return json(res,200,{balance:String(await provider.getBalance(getAddress(walletBalance[1])))});
    if(req.method!=='GET')return json(res,405,{error:'Use GET'});
    const asset=Object.hasOwn(assets,path)&&assets[path];
    if(!asset)return json(res,404,{error:'Unknown route'});
    const bytes=await readFile('dist/'+asset[0]);
    res.writeHead(200,{'content-type':asset[1],'cache-control':'no-cache','x-content-type-options':'nosniff',
      'referrer-policy':'no-referrer'});res.end(bytes);
  }catch(error){json(res,422,{error:error.shortMessage||error.message});}
}).listen(port,host,()=>console.log('Blackout Checkout matcher listening on '+host+':'+port));
