const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const swift = fs.readFileSync('Sources/GalaCore/Search.swift','utf8');
const script = swift.split('public static let javascript = #"""')[1].split('"""#')[0];
function scrape(text){return vm.runInNewContext(script,{document:{body:{innerText:text},title:'Provider'},location:{href:'https://www.agoda.com/search'}});}
const fixture = scrape('Total PHP 12,345.67 taxes included. From ₱799 per person. Use code TESTONLY. Promo code: SAMPLE2026');
assert.equal(fixture.prices[0].amount,1234567);
assert.equal(fixture.prices[1].amount,79900);
assert.equal(fixture.blocked,false);
assert.deepEqual(Array.from(fixture.codes),['TESTONLY','SAMPLE2026']);
assert.equal(scrape('Verify you are human').blocked,true);
assert.equal(scrape('USD 50 or TWD 200').prices.length,0);
assert.equal(scrape('No available flight').prices.length,0);
assert.equal(scrape('Enter your promo code here').codes.length,0);
const many=scrape(Array.from({length:100},(_,i)=>`Trip ${i} PHP ${i+1} total`).join('\n'));
assert.ok(many.prices.length<=60);
console.log('9 capture assertions passed; currency, verification, promo candidates and bounded output checked.');
