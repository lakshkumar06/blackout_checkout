import {getAddress,isHexString,Signature,verifyTypedData,ZeroAddress} from 'ethers';

export const CHAIN=5042002;
export const receiveTypes={Receive:[
  {name:'id',type:'bytes16'},{name:'vendor',type:'address'},
  {name:'amount',type:'uint256'},{name:'deadline',type:'uint64'}
]};
export const sendTypes={Send:[
  {name:'id',type:'bytes16'},{name:'vendor',type:'address'},
  {name:'payer',type:'address'},{name:'amount',type:'uint256'},{name:'deadline',type:'uint64'}
]};
export const cancelTypes={Cancel:[
  {name:'id',type:'bytes16'},{name:'vendor',type:'address'}
]};
export const escrowAbi=[
  'function DOMAIN_SEPARATOR() view returns (bytes32)',
  'function balanceOf(address) view returns (uint256)',
  'function settled(bytes32) view returns (bool)',
  'function orderKey(address,bytes16) pure returns (bytes32)',
  'function deposit() payable',
  'function withdraw(uint256)',
  'function settle((bytes16 id,address vendor,address payer,uint256 amount,uint64 deadline),bytes,bytes)',
  'event OrderPaid(bytes16 indexed orderId,address indexed vendor,address indexed payer,uint256 amount)'
];

export function domain(contract){return {name:'Blackout Checkout',version:'2',chainId:CHAIN,verifyingContract:getAddress(contract)};}
function fail(message){throw Error(message);}
function address(value){const result=getAddress(value);if(result===ZeroAddress)fail('Zero address');return result;}
function signature(value){
  if(typeof value!=='string'||!isHexString(value,65))fail('Invalid signature');
  return Signature.from(value).serialized;
}
function base(input,expectedContract){
  if(!input||input.v!==2||input.chain!==CHAIN||!isHexString(input.id,16)||BigInt(input.id)===0n)fail('Invalid intent');
  const contract=address(input.contract),vendor=address(input.vendor);
  if(expectedContract&&contract!==address(expectedContract))fail('Wrong checkout contract');
  if(typeof input.amount!=='string'||!/^[1-9][0-9]{0,77}$/.test(input.amount)||BigInt(input.amount)>=2n**256n)fail('Invalid amount');
  const deadline=Number(input.deadline);
  if(!Number.isSafeInteger(deadline)||deadline<=0||deadline>2**64-1)fail('Invalid deadline');
  return {v:2,chain:CHAIN,contract,id:input.id.toLowerCase(),vendor,amount:input.amount,deadline};
}
export function normalizeReceive(input,expectedContract){
  if(input?.kind!=='receive')fail('Not a receive intent');
  return {...base(input,expectedContract),kind:'receive',signature:signature(input.signature)};
}
export function normalizeSend(input,expectedContract){
  if(input?.kind!=='send')fail('Not a send intent');
  return {...base(input,expectedContract),kind:'send',payer:address(input.payer),signature:signature(input.signature)};
}
export function receiveValue(o){return {id:o.id,vendor:o.vendor,amount:o.amount,deadline:o.deadline};}
export function sendValue(o){return {...receiveValue(o),payer:o.payer};}
export function verifyReceive(input,expectedContract){
  const o=normalizeReceive(input,expectedContract);
  if(verifyTypedData(domain(o.contract),receiveTypes,receiveValue(o),o.signature)!==o.vendor)fail('Invalid merchant signature');
  return o;
}
export function verifySend(input,expectedContract){
  const o=normalizeSend(input,expectedContract);
  if(verifyTypedData(domain(o.contract),sendTypes,sendValue(o),o.signature)!==o.payer)fail('Invalid customer signature');
  return o;
}
export function verifyCancel(input,expectedContract){
  if(!input||input.v!==2||input.kind!=='cancel'||input.chain!==CHAIN||!isHexString(input.id,16)||BigInt(input.id)===0n)fail('Invalid cancellation');
  const contract=address(input.contract),vendor=address(input.vendor),id=input.id.toLowerCase();
  if(expectedContract&&contract!==address(expectedContract))fail('Wrong checkout contract');
  const signed=signature(input.signature);
  if(verifyTypedData(domain(contract),cancelTypes,{id,vendor},signed)!==vendor)fail('Invalid merchant signature');
  return {v:2,kind:'cancel',chain:CHAIN,contract,id,vendor,signature:signed};
}
export function match(receive,send){
  if(!receive||!send)return false;
  return ['chain','contract','id','vendor','amount','deadline'].every(k=>receive[k]===send[k]);
}
export function intentKey(o){return o.vendor.toLowerCase()+':'+o.id;}
