import solc from 'solc';
import { readFile,mkdir,writeFile } from 'node:fs/promises';
const source=await readFile('contracts/BlackoutCheckout.sol','utf8');
const input={language:'Solidity',sources:{'BlackoutCheckout.sol':{content:source}},settings:{
  optimizer:{enabled:true,runs:200},evmVersion:'paris',outputSelection:{'*':{'*':['abi','evm.bytecode.object','evm.deployedBytecode.object','evm.deployedBytecode.immutableReferences']}}}};
const output=JSON.parse(solc.compile(JSON.stringify(input)));
for(const error of output.errors||[]) if(error.severity==='error')throw Error(error.formattedMessage);
const c=output.contracts['BlackoutCheckout.sol'].BlackoutCheckout;
await mkdir('artifacts',{recursive:true});
await writeFile('artifacts/contract.json',JSON.stringify({abi:c.abi,bytecode:'0x'+c.evm.bytecode.object,
  runtime:'0x'+c.evm.deployedBytecode.object,immutableReferences:c.evm.deployedBytecode.immutableReferences}));
