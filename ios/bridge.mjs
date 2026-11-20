import {Wallet, verifyTypedData, getAddress} from 'ethers';
const chain = 5042002;
const receiveTypes = {Receive:[{name:'id',type:'bytes16'},{name:'vendor',type:'address'},{name:'amount',type:'uint256'},{name:'deadline',type:'uint64'}]};
const sendTypes = {Send:[{name:'id',type:'bytes16'},{name:'vendor',type:'address'},{name:'payer',type:'address'},{name:'amount',type:'uint256'},{name:'deadline',type:'uint64'}]};
const domain = contract => ({name:'Blackout Checkout',version:'2',chainId:chain,verifyingContract:getAddress(contract)});
function checkReceive(o,contract){
  if(o.v!==2||o.kind!=='receive'||o.chain!==chain||getAddress(o.contract)!==getAddress(contract)||!/^0x[0-9a-fA-F]{32}$/.test(o.id)||!/^\d+$/.test(o.amount)||BigInt(o.amount)<=0n||!Number.isSafeInteger(o.deadline)||o.deadline<=Math.floor(Date.now()/1000))throw Error('Invalid or expired invoice');
  const vendor=getAddress(o.vendor), value={id:o.id,vendor,amount:o.amount,deadline:o.deadline};
  if(verifyTypedData(domain(contract),receiveTypes,value,o.signature)!==vendor)throw Error('Merchant signature invalid');
  return {...o,vendor};
}
window.Blackout={
  address:key=>new Wallet(key).address,
  signDeposit:async (key,contract,amount,nonce,gasPrice)=>{
    const wallet=new Wallet(key);
    return await wallet.signTransaction({to:getAddress(contract),value:BigInt(amount),data:"0xd0e30db0",nonce:Number(BigInt(nonce)),gasLimit:100000n,gasPrice:BigInt(gasPrice),chainId:chain,type:0});
  },
  verifyReceive:async (json,contract)=>JSON.stringify(checkReceive(JSON.parse(json),contract)),
  sign:async(key,json,contract)=>{
    const receive=checkReceive(JSON.parse(json),contract),wallet=new Wallet(key);
    const base={v:2,kind:'send',chain,contract:getAddress(contract),id:receive.id,vendor:receive.vendor,payer:wallet.address,amount:receive.amount,deadline:receive.deadline};
    const value={id:base.id,vendor:base.vendor,payer:base.payer,amount:base.amount,deadline:base.deadline};
    const signature=await wallet.signTypedData(domain(contract),sendTypes,value);
    return JSON.stringify({...base,signature});
  }
};
