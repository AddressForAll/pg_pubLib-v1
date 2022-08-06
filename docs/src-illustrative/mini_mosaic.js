
// // //
// Lib:

function int_to_hcode(x,isbase4 = false, digits = 5) {
  return x.toString(2 + (isbase4?2:0)).padStart(digits,'0')
}

function rnd_to_hcode(isbase4 = false, digits = 5) {
  let radix = 2 + (isbase4?2:0)
  let max = radix**digits - 1
  return int_to_hcode( Math.round(Math.random()*max), isbase4, digits)
}

// // // // // // // // //
// Data Build Algorithms

function generate_setOfItems_rangeBytes(maxBytes=60, minBytes=0, hcode_isbase4=false, hcode_digits=5) {
  let S = new Set()
  for(let i=minBytes; i<=maxBytes; i++) {
    S.add( {hcode:rnd_to_hcode(hcode_isbase4,hcode_digits), bytes:i} )
  }
  return S
}
	//let S1 = generate_setOfItems_rangeBytes(5)
	//console.log(S1)
	
function generate_setOfUnicItems(nItems=10, maxBytes=60, minBytes=0, hcode_isbase4=false, hcode_digits=5) {
  let hcodes = new Set()
  for(let safe=0; safe<=nItems*10 && hcodes.size<nItems; safe++)
    hcodes.add( rnd_to_hcode(hcode_isbase4,hcode_digits) )
  let S = new Set()
  for (let hcode of hcodes) {
    bytes = Math.round( Math.random() * (maxBytes-minBytes) ) + minBytes
    S.add( {hcode:hcode, bytes:bytes} )
  }
  return S
}

// // // // // // 
// Main algorithms:

function mosaic_byPrefix(S,prefix_size=3) {
  let mosaic = {}
  for (let e of S) {
  	let prefix = e.hcode.substring(0,prefix_size)
  	let bytesSum = e.bytes
  	let items = {}
  	items[e.hcode] = e.bytes
  	if (prefix in mosaic) {
  	  	bytesSum += mosaic[prefix].bytesSum
  	  	Object.assign(items, mosaic[prefix].items)
  	}
  	mosaic[prefix] = {bytesSum:bytesSum,items:items}
  }
  return mosaic
}


function mosaic_tryReduce(M, treshold=250) {
  let mosaic = {} // bypass subset of M
  let parent = {} // prefix codes
  for (let cod in M) {
        let prefix = cod.substring(0, cod.length - 1)
        let e = M[cod]
        if ( e.bytesSum < treshold ) {
           if (!(prefix in parent)) parent[prefix] = {bytesSum:0,items:{}}
           parent[prefix].bytesSum += e.bytesSum
           Object.assign(parent[prefix].items, e.items)
        } else
         	mosaic[cod] = e
  }
  Object.assign(mosaic, parent)
  return mosaic
}



// // // //
// Report:

let cnf = {nItems:25, maxBytes:60, minBytes:5, hcode_isbase4:false, hcode_digits:5, treshold:250};

let S2 = generate_setOfUnicItems(...Object.values(cnf))
console.log("S2 and configs:",cnf)
console.log(S2)
//process.exit(1)


console.log("\nS2 mosaic:")
let m = mosaic_byPrefix(S2,2)
console.log(m)

console.log("\nReduced mosaic:")
m = mosaic_tryReduce(m,cnf.treshold)
console.log(m)

