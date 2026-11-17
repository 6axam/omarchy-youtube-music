const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const path = require('path');
const script = fs.readFileSync(path.join(__dirname, '..', 'bridge', 'page.js'), 'utf8');
let clicked = null;
const entries = Array.from({length: 50}, (_, i) => ({playlistPanelVideoRenderer: {
  videoId: `video${i}`, playlistSetVideoId: `set${i}`, title: {runs:[{text:`Song ${i}`}]},
  shortBylineText: {runs:[{text:'Artist'}]}, longBylineText:{runs:[{text:'Artist • Album • 2024'}]},
  selected:i===0, navigationEndpoint:{watchEndpoint:{index:i,videoId:`video${i}`,playlistSetVideoId:`set${i}`}}
}}));
function row(data, marker) { return {data, querySelector: s => s === 'ytmusic-play-button-renderer' ? {click:() => {clicked = marker}} : null, click:() => {clicked = `row:${marker}`}}; }
const wrapped = entries[3].playlistPanelVideoRenderer;
entries[3] = {playlistPanelVideoWrapperRenderer: {primaryRenderer: {playlistPanelVideoRenderer: wrapped}}};
const rows = entries.map((e,i) => row(i === 3 ? entries[3] : e.playlistPanelVideoRenderer, i));
rows.unshift(...Array.from({length:3}, (_,i) => row({videoId:`extra${i}`}, `extra${i}`)));
const queue = {data:entries, querySelectorAll: () => rows};
const control = name => ({disabled:false, hasAttribute:()=>false, getAttribute:()=>null, querySelector:()=>null, click:()=>{clicked=name}});
const controls = {'.shuffle':control('shuffle'), '.repeat':control('repeat')};
const bar = {shuffleOn:true, repeatMode:'ALL', isShuffleDisabled:false, isRepeatButtonDisabled:false, querySelector: s => controls[s] || null};
const video = {paused:true, ended:false, duration:120, currentTime:0};
const context = {document:{querySelector: s => ({'ytmusic-player-queue':queue,'ytmusic-player-bar':bar,video})[s]}, navigator:{mediaSession:{metadata:{title:'Song 0',artist:'Artist'}}}};
const run = request => vm.runInNewContext(script.replace('__REQUEST__',JSON.stringify(request)), context);
const state = run({command:'state'});
assert.strictEqual(state.queue.length,50);
assert.strictEqual(state.shuffle,true);
assert.strictEqual(state.repeat,'all');
assert.strictEqual(state.canShuffle,true);
assert.strictEqual(state.canRepeat,true);
run({command:'shuffle'}); assert.strictEqual(clicked,'shuffle');
run({command:'repeat'}); assert.strictEqual(clicked,'repeat');
bar.repeatMode = 'ONE'; assert.strictEqual(run({command:'state'}).repeat,'one');
bar.repeatMode = 'NONE'; assert.strictEqual(run({command:'state'}).repeat,'off');
bar.isShuffleDisabled = true; assert.throws(() => run({command:'shuffle'}), /unavailable/);
bar.isShuffleDisabled = false;
assert.strictEqual(state.queue[3].title,'Song 3');
assert.strictEqual(state.queue[3].index,3);
assert(state.queue.every(item => item.title));
run({command:'select',index:3,id:state.queue[3].id});
assert.strictEqual(clicked,3);
assert.strictEqual(state.queue[4].title,'Song 4');
assert.strictEqual(state.queue[4].artist,'Artist');
run({command:'select',index:4,id:state.queue[4].id});
assert.strictEqual(clicked,4);
assert.throws(() => run({command:'select',index:4,id:'wrong'}), /Queue changed/);
rows.push(row(entries[4].playlistPanelVideoRenderer,'duplicate'));
assert.throws(() => run({command:'select',index:4,id:state.queue[4].id}), /ambiguous/);
console.log('page.js fixture passed');
