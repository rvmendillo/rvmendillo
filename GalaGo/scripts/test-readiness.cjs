const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync('Sources/GalaCore/Retrieval.swift','utf8');
const script=source.split('public static let javascript = #"""')[1].split('"""#')[0];
function read(text,fields=[]){return vm.runInNewContext(script,{document:{body:{innerText:text},querySelectorAll:()=>fields.map(f=>({getClientRects:()=>f.hidden?[]:[{}],value:f.value,getAttribute:k=>k==='formcontrolname'?f.name:null}))},location:{href:'https://www.cebupacificair.com/en-PH/booking/select-flight?o1=MNL&d1=CEB'}});}
assert.equal(read('Flights PHP 1,200').priceReady,true);
assert.equal(read('Loading flights…').priceReady,false);
assert.equal(read('USD 50').priceReady,false);
assert.equal(read('No flights available').unavailable,true);
assert.equal(read('Verify you are human').blocked,true);
assert.equal(read('Use code SAVE10').codeReady,true);
const good=read('MNL → CEB',[{name:'origin',value:'Manila (MNL)'},{name:'destination',value:'Cebu (CEB)'},{name:'password',value:'NOT_READ'}]);
assert.deepEqual(Array.from(good.origins),['MNL']);assert.deepEqual(Array.from(good.destinations),['CEB']);
assert.deepEqual(Array.from(read('MNL ↔ MNL').routePairs,x=>Array.from(x)),[['MNL','MNL']]);
assert.equal(read('',[{name:'destination',value:'Cebu (CEB)',hidden:true}]).destinations.length,0);
console.log('10 page-readiness / public route-field assertions passed.');
