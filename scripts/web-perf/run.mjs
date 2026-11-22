
import {chromium} from 'playwright-core';
import {createServer} from 'node:http';
import {readFile, mkdir, writeFile} from 'node:fs/promises';
import {existsSync} from 'node:fs';
import {resolve, relative, join, extname} from 'node:path';

const repo = resolve(import.meta.dirname, '../..');
const option = (flag, fallback) => {
  const pos = process.argv.indexOf(flag);
  return pos < 0 ? fallback : process.argv[pos + 1];
};
const has = flag => process.argv.includes(flag);
const runs = Number(option('--runs', '3'));
const cycles = Number(option('--cycles', '3'));
const output = resolve(option('--output', join(repo, 'build/reports/web-performance')));
const bundle = resolve(option('--bundle', join(repo, 'build/web')));
const seedBundle = resolve(option('--seed-bundle', join(repo, 'build/web-perf')));
const binary = option('--browser', process.env.FLEX_CHROME_BINARY || (existsSync('/usr/bin/chromium') ? '/usr/bin/chromium' : chromium.executablePath()));
const devices = {
  desktop: {viewport:{width:1440,height:900}, scale:1, cpu:1},
  mobile: {viewport:{width:390,height:844}, scale:2, cpu:4, isMobile:true, hasTouch:true},
};
const selected = option('--profile', 'all') === 'all' ? Object.keys(devices) : [option('--profile', 'all')];
if (!Number.isInteger(runs) || runs < 1 || runs > 30 || !Number.isInteger(cycles) || cycles < 1 || cycles > 30) throw Error('runs/cycles must be 1..30');
if (selected.some(name => !devices[name])) throw Error('Unknown --profile');
if (!existsSync(join(bundle,'index.html'))) throw Error('Missing release build: '+bundle);
if (!has('--no-stress') && !existsSync(join(seedBundle,'index.html'))) throw Error('Missing seed build: '+seedBundle);

const mime = {'.html':'text/html', '.js':'application/javascript', '.wasm':'application/wasm', '.json':'application/json', '.css':'text/css', '.png':'image/png', '.svg':'image/svg+xml', '.woff2':'font/woff2', '.otf':'font/otf', '.ttf':'font/ttf'};
const server = createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const pathname = decodeURIComponent(url.pathname);
  const isSeed = pathname.startsWith('/seed/');
  const root = isSeed ? seedBundle : bundle;
  const name = isSeed ? pathname.slice(6) : pathname.slice(1);
  const file = resolve(root, name || 'index.html');
  if (relative(root,file).startsWith('..') || !file.startsWith(root)) {res.writeHead(403).end();return;}
  try {
    const data = await readFile(file);
    res.setHeader('Content-Type', mime[extname(file)] || 'application/octet-stream');
    res.setHeader('Content-Length',data.length);
    res.setHeader('Cache-Control',extname(file)==='.html'?'no-cache':'public,max-age=3600');
    res.end(data);
  } catch {res.writeHead(404).end('Not found');}
});
const pct = (items, q) => {
  if (!items.length) return null;
  const a = [...items].sort((a,b)=>a-b);
  return Math.round(a[Math.ceil(a.length*q)-1]*10)/10;
};
const rnd = n => Number.isFinite(n) ? Math.round(n*10)/10 : null;
const escapeHtml = text => String(text ?? '').replace(/[&<>"']/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'})[ch]);
async function ready(page) {
  await page.locator('flt-semantics-placeholder').waitFor({timeout:60000});
  await page.locator('flt-semantics-placeholder').evaluate(element=>element.click());
  await page.locator('flt-semantics-host flt-semantics[role="button"]').filter({hasText:/^History/}).first().waitFor({timeout:60000});
}
async function tab(page,name) {
  const el = page.locator('flt-semantics-host flt-semantics[role="button"]').filter({hasText:new RegExp('^'+name)}).first();
  await el.waitFor({timeout:15000});
  const start = await page.evaluate(()=>performance.now());
  await el.click({timeout:15000});
  if(name==='Settings') await page.waitForFunction(()=>document.body.innerText.includes('Data management'),null,{timeout:10000});
  else await page.waitForFunction(name=>[...document.querySelectorAll('flt-semantics-host flt-semantics[role="button"]')].some(el=>el.textContent.trim().startsWith(name) && (el.getAttribute('aria-current')==='true'||el.getAttribute('aria-selected')==='true')), name, {timeout:10000});
  return rnd((await page.evaluate(async()=>{await new Promise(done=>requestAnimationFrame(()=>requestAnimationFrame(done)));return performance.now();}))-start);
}
async function heap(cdp) {
  await cdp.send('HeapProfiler.collectGarbage');
  const {metrics} = await cdp.send('Performance.getMetrics');
  return rnd((metrics.find(x=>x.name==='JSHeapUsedSize')?.value||0)/1048576);
}
async function frameProbe(page,device,scroll) {
  const frames = page.evaluate(()=>new Promise(resolve=>{
    const times=[];let start=0;
    const tick=now=>{if (!start) start=now;times.push(now);if(now-start<1500)requestAnimationFrame(tick);else resolve(times.slice(1).map((t,i)=>t-times[i]));};
    requestAnimationFrame(tick);
  }));
  await page.mouse.move(device.viewport.width*.65,device.viewport.height*.53);
  if (scroll) for(let i=0;i<8;i++){await page.mouse.wheel(0,280);await page.waitForTimeout(65);}
  return await frames;
}
async function runDevice(browser,name,origin,report) {
  const device=devices[name];
  const context=await browser.newContext({viewport:device.viewport,deviceScaleFactor:device.scale,isMobile:device.isMobile||false,hasTouch:device.hasTouch||false,locale:'en-NZ',reducedMotion:'reduce'});
  const page=await context.newPage();
  const errors=[];
  try {
    const cdp=await context.newCDPSession(page);
    await cdp.send('Network.enable');
    await cdp.send('Performance.enable');
    await cdp.send('HeapProfiler.enable');
    await cdp.send('Emulation.setCPUThrottlingRate',{rate:device.cpu});
    if(name==='mobile') await cdp.send('Network.emulateNetworkConditions',{offline:false,latency:80,downloadThroughput:625000,uploadThroughput:187500});
    page.on('pageerror',err=>errors.push('Uncaught: '+err.message));
    page.on('response',response=>{if(response.status()>=400) errors.push('HTTP '+response.status()+' '+response.url());});
    await page.addInitScript(()=>{
      window.__perfLongTasks=[];
      try {new PerformanceObserver(list=>window.__perfLongTasks.push(...list.getEntries().map(e=>({start:e.startTime,duration:e.duration})))).observe({type:'longtask',buffered:true});}catch{}
    });
    for(const workload of has('--no-stress')?['empty']:['empty','loaded']){
      if(workload==='loaded'){
        await cdp.send('Network.setCacheDisabled',{cacheDisabled:false});
        await page.goto(origin+'/seed/?seed=1',{waitUntil:'domcontentloaded',timeout:60000});
        await ready(page);
        await page.waitForFunction(()=>document.body.innerText.includes('Perf fixture'),null,{timeout:90000});
      }
      const initialErrors=errors.length;
      const samples=[];
      for(let i=0;i<runs;i++){
        await cdp.send('Network.setCacheDisabled',{cacheDisabled:true});
        await page.goto(origin+'/',{waitUntil:'domcontentloaded',timeout:60000});
        await ready(page);
        samples.push(await page.evaluate(()=>({
          startupMs:Math.round(performance.now()*10)/10,
          fcpMs:performance.getEntriesByName('first-contentful-paint')[0]?.startTime??null,
          transferBytes:performance.getEntriesByType('resource').reduce((s,e)=>s+(e.transferSize||0),0),
          resources:performance.getEntriesByType('resource').length,
          longTasks:window.__perfLongTasks||[],
        })));
      }
      await cdp.send('Network.setCacheDisabled',{cacheDisabled:false});
      await page.reload({waitUntil:'domcontentloaded',timeout:60000});
      await ready(page);
      const warmMs=rnd(await page.evaluate(()=>performance.now()));
      const screenshot=name+'-'+workload+'.png';
      await page.screenshot({path:join(output,screenshot),animations:'disabled'});
      const nav=[];
      const heapBefore=await heap(cdp);
      for(let i=0;i<cycles;i++){
        for(const name of ['Plans','Graphs','Timer','History']){
          if(await page.locator('flt-semantics-host flt-semantics[role="button"]').filter({hasText:new RegExp('^'+name)}).count()) nav.push({tab:name,ms:await tab(page,name)});
        }
      }
      const heapAfter=await heap(cdp);
      if(await page.locator('flt-semantics-host flt-semantics[role="button"]').filter({hasText:/^Settings/}).count()){
        nav.push({tab:'Settings',ms:await tab(page,'Settings')});
        await page.reload({waitUntil:'domcontentloaded',timeout:60000});
        await ready(page);
      }
      await tab(page,'History');
      const beforeScroll=await page.screenshot({animations:'disabled'});
      const frames=await frameProbe(page,device,workload==='loaded');
      const scrollScreenshot=name+'-'+workload+'-scroll.png';
      const afterScroll=await page.screenshot({path:join(output,scrollScreenshot),animations:'disabled'});
      const scrollMoved=!beforeScroll.equals(afterScroll);
      const interactions={};
      if(workload==='loaded'){
        if(!scrollMoved) errors.push('History did not visibly scroll under load');
        await tab(page,'History');
        const search=page.locator('flt-semantics-host input[aria-label="Search history..."]');
        await search.waitFor({timeout:12000});
        const searchStart=await page.evaluate(()=>performance.now());
        await search.click({force:true});
        await page.keyboard.insertText('Perf fixture 007');
        await page.waitForFunction(()=>{
          const text=document.body.innerText;
          return text.includes('Perf fixture 007')&&!text.includes('Perf fixture 000');
        },null,{timeout:12000});
        interactions.searchMs=rnd((await page.evaluate(()=>performance.now()))-searchStart);
        await page.screenshot({path:join(output,name+'-search.png'),animations:'disabled'});
        interactions.graphNavigationMs=await tab(page,'Graphs');
        await page.waitForFunction(()=>document.body.innerText.includes('Perf fixture'),null,{timeout:12000});
        await page.screenshot({path:join(output,name+'-graphs.png'),animations:'disabled'});
        const graphTile=page.locator('flt-semantics-host flt-semantics[role="button"]').filter({hasText:/^Perf fixture 000/}).first();
        await graphTile.waitFor({timeout:12000});
        const detailStart=await page.evaluate(()=>performance.now());
        await graphTile.click({timeout:12000});
        await page.waitForFunction(()=>document.body.innerText.includes('Perf fixture 000') && !document.body.innerText.includes('Perf fixture 001'),null,{timeout:12000});
        interactions.graphDetailMs=rnd((await page.evaluate(()=>performance.now()))-detailStart);
        await page.screenshot({path:join(output,name+'-graph-detail.png'),animations:'disabled'});
      }
      const caseErrors=errors.slice(initialErrors);
      const summary={
        startupP50Ms:pct(samples.map(x=>x.startupMs),.5),
        startupP95Ms:pct(samples.map(x=>x.startupMs),.95),
        warmStartupMs:warmMs,
        navigationP50Ms:pct(nav.map(x=>x.ms),.5),
        navigationP95Ms:pct(nav.map(x=>x.ms),.95),
        scrollFrameP95Ms:pct(frames,.95),
        scrollLongFrames:frames.filter(x=>x>50).length,
        frameCount:frames.length,
        heapDeltaMb:rnd(heapAfter-heapBefore),
        longTaskCount:samples.reduce((s,x)=>s+x.longTasks.length,0),
        errors:caseErrors.length,
        searchMs:interactions.searchMs??null,
        graphNavigationMs:interactions.graphNavigationMs??null,
        scrollMoved,
      };
      report.cases.push({profile:name,workload,samples,nav,interactions,summary,errors:caseErrors,screenshot,scrollScreenshot});
      console.log(name+'/'+workload+': startup p95 '+summary.startupP95Ms+' ms; warm '+warmMs+' ms; nav p95 '+summary.navigationP95Ms+' ms; frame p95 '+summary.scrollFrameP95Ms+' ms; heap delta '+summary.heapDeltaMb+' MB; errors '+summary.errors);
    }
  } catch (error) {
    await page.screenshot({path:join(output,name+'-failure.png')}).catch(()=>{});
    console.error('Failed app state:',await page.evaluate(()=>({text:document.body.innerText.slice(0,1000),html:document.body.innerHTML.slice(0,1000)})).catch(()=>null));
    console.error('Errors:',errors);
    throw error;
  } finally {await context.close();}
}
function html(report) {
  const rows=report.cases.map(row=>{
    const s=row.summary;
    const cells=[row.profile,row.workload,s.startupP50Ms,s.startupP95Ms,s.warmStartupMs,s.navigationP95Ms,s.scrollFrameP95Ms,s.scrollLongFrames,s.heapDeltaMb,s.longTaskCount,s.errors].map(x=>'<td>'+escapeHtml(x)+'</td>').join('');
    return '<tr>'+cells+'<td><a href="'+row.screenshot+'">Screenshot</a></td></tr>';
  }).join('');
  const headings=['Device','Workload','Startup p50 ms','Startup p95 ms','Warm ms','Nav p95 ms','Frame p95 ms','Frames >50ms','Heap delta MB','Long tasks','Errors','Visual'].map(x=>'<th>'+x+'</th>').join('');
  return '<!doctype html><html lang="en"><meta charset="utf-8"><title>Flex web performance</title><style>body{background:#111521;color:#e9eafa;font:15px system-ui;margin:40px}table{border-collapse:collapse;width:100%}td,th{padding:10px;border-bottom:1px solid #34394b;text-align:right}td:first-child,td:nth-child(2),th:first-child,th:nth-child(2){text-align:left}a{color:#afcaff}</style><h1>Flex web performance</h1><p>'+escapeHtml(report.startedAt)+' · '+report.runs+' samples per case · '+report.cycles+' navigation cycles · '+escapeHtml(report.browser)+'</p><table><thead><tr>'+headings+'</tr></thead><tbody>'+rows+'</tbody></table><h2>Checks: '+(report.failures.length?'Failed':'Passed')+'</h2><ul>'+report.failures.map(x=>'<li>'+escapeHtml(x)+'</li>').join('')+'</ul><p>Readiness: first accessible app tab. Frame intervals: main-thread requestAnimationFrame, not GPU raster frames. Mobile: 4x CPU throttle, 5 Mbit/s network, 80 ms latency. Test data is isolated in a fresh browser context.</p></html>';
}
await mkdir(output,{recursive:true});
await new Promise(done=>server.listen(0,'127.0.0.1',done));
const origin='http://127.0.0.1:'+server.address().port;
const report={startedAt:new Date().toISOString(),browser:binary,runs,cycles,cases:[],failures:[]};
let browser;
try {
  browser=await chromium.launch({executablePath:binary,headless:true,args:['--no-sandbox','--disable-background-timer-throttling','--disable-renderer-backgrounding']});
  for(const name of selected) try{await runDevice(browser,name,origin,report);}catch(err){report.failures.push(name+': '+(err.stack||err));}
  const budgets=JSON.parse(await readFile(join(import.meta.dirname,'budgets.json'),'utf8'));
  if(!has('--no-budgets'))for(const item of report.cases)for(const [metric,max] of Object.entries(budgets[item.profile])){
    if(item.summary[metric]!=null && item.summary[metric]>max)report.failures.push(item.profile+'/'+item.workload+' '+metric+' '+item.summary[metric]+' > '+max);
  }
} finally {
  await browser?.close();
  server.close();
  await writeFile(join(output,'results.json'),JSON.stringify(report,null,2)+'\n');
  await writeFile(join(output,'index.html'),html(report));
}
console.log('Report: '+join(output,'index.html'));
if(report.failures.length){console.error(report.failures.join('\n'));process.exitCode=1;}
