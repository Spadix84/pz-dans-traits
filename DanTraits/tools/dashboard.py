"""Project Zomboid Vitality Project live dashboard.

Serves a browser page on http://127.0.0.1:8642 that shows what the mod's
telemetry file says twice a second and lets you send commands back to the
game. Standard library only. Run it with the game open (single player):

    python dashboard.py            # default folder: <user>/Zomboid/Lua
    python dashboard.py --dir X    # read/write files in folder X instead

Files: DanTraits_Telemetry.json (game -> here), DanTraits_Commands.txt (here -> game).
"""
import argparse
import json
import os
import sys
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = 8642
TELEMETRY = "DanTraits_Telemetry.json"
COMMANDS = "DanTraits_Commands.txt"

HTML = r"""<!doctype html>
<html><head><meta charset="utf-8"><title>Project Zomboid Vitality Project</title>
<style>
:root{--bg:#14161a;--card:#1d2026;--line:#2b2f37;--fg:#e6e6e6;--dim:#8b919c;--ok:#5bbf7a;--warn:#e0b04a;--bad:#e05a5a;--acc:#5aa7e0}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:14px/1.4 system-ui,Segoe UI,sans-serif}
header{display:flex;gap:16px;align-items:center;padding:10px 16px;border-bottom:1px solid var(--line);position:sticky;top:0;background:var(--bg);z-index:2;flex-wrap:wrap}
header h1{font-size:16px;margin:0}.dim{color:var(--dim)}.chip{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:2px 8px;font-size:12px}
#status{margin-left:auto}.live{color:var(--ok)}.stale{color:var(--bad)}
.layout{display:flex;align-items:flex-start;gap:12px;padding:12px 16px}
main{flex:1;min-width:0;display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:12px}
#cmdcard{width:380px;flex:none;position:sticky;top:64px;max-height:calc(100vh - 80px);overflow:auto}
@media(max-width:1100px){.layout{flex-direction:column}#cmdcard{width:auto;position:static;max-height:none}}
.card{background:var(--card);border:1px solid var(--line);border-radius:8px;padding:10px 12px}
.card h2{font-size:13px;margin:0 0 8px;color:var(--dim);text-transform:uppercase;letter-spacing:.04em;display:flex;justify-content:space-between}
.big{font-size:34px;font-weight:600;line-height:1}.row{display:flex;justify-content:space-between;gap:8px;padding:2px 0;border-bottom:1px dashed var(--line)}.row:last-child{border:0}
.bar{height:6px;background:#0d0f12;border-radius:3px;overflow:hidden;margin:4px 0 6px}.bar i{display:block;height:100%;background:var(--acc)}
canvas{width:100%;height:56px;display:block;margin-top:6px}
.ok{color:var(--ok)}.warn{color:var(--warn)}.bad{color:var(--bad)}
.wide{grid-column:1/-1}
#cmd{display:flex;gap:8px}#cmd input{flex:1;background:#0d0f12;color:var(--fg);border:1px solid var(--line);border-radius:6px;padding:8px 10px;font:14px monospace}
button{background:#262a32;color:var(--fg);border:1px solid var(--line);border-radius:6px;padding:6px 10px;cursor:pointer;font-size:13px}button:hover{border-color:var(--acc)}
.groups{display:flex;flex-direction:column;gap:6px;margin-top:8px}.group{display:flex;flex-wrap:wrap;gap:4px;align-items:center;padding:4px 0;border-top:1px dashed var(--line)}.group b{color:var(--dim);font-weight:600;font-size:11px;width:100%;text-transform:uppercase;letter-spacing:.04em}.group button{padding:3px 7px;font-size:12px}
pre{margin:0;font:12px/1.4 monospace;white-space:pre-wrap;color:var(--dim);max-height:220px;overflow:auto}
table{width:100%;border-collapse:collapse;font:12px monospace}td{padding:2px 4px;border-bottom:1px solid var(--line);vertical-align:top}td:first-child{color:var(--dim);width:45%}
details summary{cursor:pointer;color:var(--dim)}
</style></head><body>
<header><h1>Project Zomboid Vitality Project</h1><span id="clock" class="dim">-</span><span id="traits"></span><span id="status" class="stale">waiting for the game</span></header>
<div class="layout"><main id="main"></main>
<script>
const H = {};            // history per key: [{t,v}]
const KEEP = 1200;       // samples (~10 min at 2/s)
let last = null, lastT = 0;
const arr = x => Array.isArray(x) ? x : [];   // Lua encodes an empty list as {}
function hist(key, v){ if(typeof v!=='number') return; const a = H[key] || (H[key]=[]); a.push(v); if(a.length>KEEP) a.shift(); }
function fmt(v,d){ if(v==null) return '-'; if(typeof v==='number') return (Math.abs(v)>=100||Number.isInteger(v))? Math.round(v).toString() : v.toFixed(d==null?2:d); if(typeof v==='boolean') return v?'yes':'no'; if(typeof v==='object') return JSON.stringify(v); return String(v); }
function spark(id,key,lo,hi,bands){ const c=document.getElementById(id); if(!c) return; const a=H[key]||[]; const W=c.width=c.clientWidth*2, Hh=c.height=112; const g=c.getContext('2d'); g.clearRect(0,0,W,Hh);
  if(bands){ for(const b of bands){ const y0=Hh-(b[1]-lo)/(hi-lo)*Hh, y1=Hh-(b[0]-lo)/(hi-lo)*Hh; g.fillStyle=b[2]; g.fillRect(0,Math.max(0,y0),W,Math.min(Hh,y1)-Math.max(0,y0)); } }
  if(a.length<2) return; g.strokeStyle='#5aa7e0'; g.lineWidth=2; g.beginPath(); a.forEach((v,i)=>{ const x=i/(KEEP-1)*W, y=Hh-Math.max(0,Math.min(1,(v-lo)/(hi-lo)))*Hh; i?g.lineTo(x,y):g.moveTo(x,y); }); g.stroke(); }
function bar(v,max,cls){ const p=Math.max(0,Math.min(1,(v||0)/max))*100; return `<div class="bar"><i style="width:${p}%;background:${cls||'var(--acc)'}"></i></div>`; }
function row(k,v,cls){ return `<div class="row"><span class="dim">${k}</span><span class="${cls||''}">${v}</span></div>`; }
function card(title,body,extra){ return `<div class="card ${extra||''}"><h2>${title}</h2>${body}</div>`; }

function render(d){
  const m=d.mod||{}, s=d.stats||{}, b=d.body||{}, x=d.derived||{};
  const has=id=>arr(d.traits).some(t=>t.toLowerCase()==='dantraits:'+id);
  for(const [k,v] of Object.entries(s)) hist('stat.'+k,v);
  for(const [k,v] of Object.entries(m)) hist('mod.'+k,v);
  hist('body.health',b.health); hist('body.weight',b.weight);
  const g=d.game||{}; document.getElementById('clock').textContent=`day ${fmt(g.day)}  ${String(g.hour??0).padStart(2,'0')}:${String(Math.floor(g.minute??0)).padStart(2,'0')}   ${fmt(d.hoursSurvived,1)} h survived`;
  document.getElementById('traits').innerHTML=arr(d.traits).map(t=>`<span class="chip">${t.replace(/^dantraits:/i,'')}</span>`).join(' ');
  const cards=[];
  // vitals
  const vit=[['panic',100],['endurance',1],['fatigue',1],['thirst',1],['hunger',1],['unhappiness',100],['stress',1],['boredom',100],['intoxication',100],['food_sickness',100],['pain',100]];
  cards.push(card('Vitals', vit.filter(v=>s[v[0]]!=null).map(v=>`<div class="row"><span class="dim">${v[0]}</span><span>${fmt(s[v[0]])}</span></div>${bar(s[v[0]],v[1])}`).join('') + row('health',fmt(b.health,1)) + bar(b.health,100,'var(--ok)') + row('weight',fmt(b.weight,1)+' kg') + row('calories',fmt(b.calories)) + row('asleep / outside / running',`${fmt(b.asleep)} / ${fmt(b.outside)} / ${fmt(b.running)}`) + row('air temp',fmt(b.temperature,1)+' C')));
  // diabetes
  if((has('diabetes1')||has('diabetes2'))&&m.glucose!=null){ const gl=m.glucose, cls=gl<70||gl>=180?(gl<55||gl>=250?'bad':'warn'):'ok';
    cards.push(card('Diabetes', `<div class="big ${cls}">${Math.round(gl)}<span class="dim" style="font-size:13px"> mg/dL</span></div><canvas id="c_glucose"></canvas>`
      + row('tier low / high',`${x.diaLow??0} / ${x.diaHigh??0}`) + row('carbs pending fast / slow',`${fmt(m.diaFast,1)} / ${fmt(m.diaSlow,1)} g`) + row('insulin on board',`${fmt(x.insulinDoses)} dose(s), ${arr(m.diaInsulin).length} shot(s)`) + row('resistance',fmt(x.diaResistance,2)) + row('metformin cover',fmt(m.diaMedMinutes)+' min') + row('keto hours',fmt(m.diaKetoHours,2)) + row('shaky (swing drop %)',fmt(x.swingDrop,2)) + row('halo in',fmt(m.diaHaloIn)))); }
  // vitality (everyone has it)
  if(m.vitality!=null){ const v=m.vitality, e=m.vitEffect||0, tiers=['Run Down','Sluggish','Normal','Fit','Thriving'], tier=v>=0.8?4:v>=0.6?3:v>=0.4?2:v>=0.2?1:0, cls=tier>=3?'ok':tier<=1?'bad':'';
    const meals=arr(m.vitMeals).map(x=>`<tr><td>${x.name}</td><td>${fmt(x.grade,2)}</td><td>${x.kcal} kcal</td><td>${fmt((d.hoursSurvived||0)-(x.hour||0),1)} h ago</td><td class="dim">${x.why||''}</td></tr>`).join('');
    cards.push(card('Vitality', `<div class="big ${cls}">${tiers[tier]}<span class="dim" style="font-size:13px"> ${Math.round(v*100)} / target ${Math.round((m.vitTarget||0)*100)}</span></div><canvas id="c_vitality"></canvas>`
      + row('effect (-1..1)',fmt(e,2),cls) + row('diet',fmt(m.vitDiet,2)) + bar(m.vitDiet,1) + row('exercise',fmt(m.vitExercise,2)) + bar(m.vitExercise,1) + row('sleep',fmt(m.vitSleep,2)) + bar(m.vitSleep,1)
      + row('food types (3 days)',fmt(m.vitVariety)) + row('last night',`${fmt(m.vitLastSleepHours,1)} h, ${fmt(m.vitLastSleepWakes)} wake(s), quality ${fmt(m.vitLastSleepQuality,2)}`) + row('night so far',`${fmt(m.vitNightHours,1)} h, ${fmt(m.vitNightWakes)} wake(s)`) + row('sleep debt (today)',fmt(m.vitSleepDebt,2),(m.vitSleepDebt||0)>=0.5?'bad':(m.vitSleepDebt||0)>=0.25?'warn':'') + bar(m.vitSleepDebt,1,'var(--warn)') + row('awake for',fmt((m.vitAwakeMin||0)/60,1)+' h') + row('carry base + vitality',`${fmt(m.vitCarryBase)} ${(m.vitCarryKg||0)>=0?'+':''}${fmt(m.vitCarryKg)} kg`)
      + `<table style="margin-top:6px">${meals||'<tr><td class="dim">no meals yet</td></tr>'}</table>`, 'wide')); }
  // asthma
  if(has('asthma')&&m.asthma!=null){ const a=m.asthma, cls=a>=0.9?'bad':a>=0.5?'warn':'ok';
    cards.push(card('Asthma', `<div class="big ${cls}">${Math.round(a*100)}<span class="dim" style="font-size:13px"> % irritation</span></div>${bar(a,1,a>=0.75?'var(--bad)':'var(--warn)')}<canvas id="c_asthma"></canvas>` + row('attack',fmt(m.asthmaAttack),m.asthmaAttack?'bad':'') + row('cough in',fmt(m.asthmaCoughIn)+' min') + row('shown tier',fmt(m.asthmaShownTier)))); }
  // mdd
  if(has('spiraling')){ cards.push(card('Major Depressive Disorder', `<div class="big ${m.mddEpisode?'bad':'ok'}">${m.mddEpisode?'EPISODE':'clear'}</div>` + row('severity',fmt(m.mddSeverity,2)) + row('hours left',fmt(m.mddHoursLeft,1)) + row('hours since end',fmt(m.mddSinceEnd,1)) + row('outdoors (rolling min/day)',fmt(m.mddOutside,0)) + row('smoke / food timer',`${fmt(m.mddSmokeTimer)} / ${fmt(m.mddFoodTimer)}`) + row('exercise regularity',fmt(x.exerciseRegularity,2)) + row('meds: days / streak / benefit',`${fmt(m.mddMedDays,1)} / ${fmt(m.mddMedStreak,1)} / ${fmt(x.mddBenefit,2)}`) + row('withdrawal min',fmt(m.mddWithdraw)) + `<canvas id="c_unhappy"></canvas>`)); }
  // gluten
  if(has('gluten')&&m.gluten!=null){ cards.push(card('Gluten Intolerance', `<div class="big ${m.gluten>=0.5?'bad':m.gluten>0?'warn':'ok'}">${Math.round(m.gluten*100)}<span class="dim" style="font-size:13px"> % flare</span></div>${bar(m.gluten,1,'var(--warn)')}` + row('pending doses',fmt(m.glutenPending,2)) + row('onset in',fmt(m.glutenOnset)+' min') + `<canvas id="c_gluten"></canvas>`)); }
  // dependent
  if(has('dependent')&&m.dryHours!=null){ cards.push(card('Dependent', `<div class="big ${m.withdrawing?'bad':'ok'}">${fmt(m.dryHours,1)}<span class="dim" style="font-size:13px"> h dry</span></div>` + row('withdrawing',fmt(m.withdrawing)) + row('tolerance',fmt(m.depTolerance,2)) + bar(m.depTolerance,1,'var(--warn)'))); }
  // hangover (everyone)
  if(m.hoLoad!=null){ const hs=m.hoActive?(m.hoSeverity||0)*Math.min(1,(m.hoHoursLeft||0)/2):0;
    cards.push(card('Hangover', `<div class="big ${m.hoActive?'bad':m.hoPending?'warn':'ok'}">${m.hoActive?'HUNGOVER':m.hoPending?'waiting to wake':m.hoDrinking?'drinking':'clear'}</div>` + row('load (drunk-hours)',fmt(m.hoLoad,2)) + bar(m.hoLoad,3,'var(--warn)') + row('severity',fmt(m.hoSeverity,2)) + row('hours left',fmt(m.hoHoursLeft,1)) + row('strength now',fmt(hs,2)))); }
  // caffeine
  if(has('caffeine')&&m.cafLevel!=null){ cards.push(card('Caffeine Dependent', `<div class="big ${(m.cafWithdraw||0)>0?'bad':'ok'}">${Math.round(m.cafLevel)}<span class="dim" style="font-size:13px"> caffeine (60 = sated)</span></div>` + bar(m.cafLevel,400) + row('hours dry',fmt(m.cafDryHours,1)) + row('withdrawal',fmt(m.cafWithdraw,2)) + bar(m.cafWithdraw,1,'var(--bad)') + row('last dose',fmt(m.cafLastDose)))); }
  // migraine
  if(has('migraine')){ cards.push(card('Migraines', `<div class="big ${m.migActive?'bad':m.migAuraLeft?'warn':'ok'}">${m.migActive?'MIGRAINE':m.migAuraLeft?'AURA':'clear'}</div>` + row('chance / 10 min',fmt(m.migChance,2)+' %') + row('severity',fmt(m.migSeverity,2)) + row('hours left',fmt(m.migHoursLeft,1)) + row('aura left (h)',fmt(m.migAuraLeft,2)) + row('hours since end',fmt(m.migSinceEnd,1)) + row('painkillers used',fmt(m.migMedsUsed)))); }
  // hemophilia
  if(has('hemophilia')){ cards.push(card('Hemophilia', `<div class="big ${(m.hemoOpen||0)>0?'bad':'ok'}">${fmt(m.hemoOpen||0)}<span class="dim" style="font-size:13px"> open bleed(s)</span></div>`)); }
  // anaemic
  if(has('anemia')&&m.anIron!=null){ cards.push(card('Anaemic', `<div class="big ${(m.anDeficit||0)>=0.5?'bad':(m.anDeficit||0)>0?'warn':'ok'}">${Math.round(m.anIron*100)}<span class="dim" style="font-size:13px"> % iron (40 = enough)</span></div>` + bar(m.anIron,1,(m.anDeficit||0)>0?'var(--warn)':'var(--acc)') + row('deficit',fmt(m.anDeficit,2)) + row('last iron from',fmt(m.anLastIron)))); }
  // arthritis
  if(has('arthritis')){ cards.push(card('Arthritis', `<div class="big ${(m.artJoint||0)>=0.5?'bad':(m.artJoint||0)>0?'warn':'ok'}">${Math.round((m.artJoint||0)*100)}<span class="dim" style="font-size:13px"> % flare</span></div>` + bar(m.artJoint,1,'var(--warn)') + row('stiffness floor',fmt(m.artStiffTarget,1)) + row('combat speed set',fmt(m.artCombatSet,2)))); }
  // everything else in mod data
  const shown=new Set(['depTolerance','hoLoad','hoActive','hoPending','hoDrinking','hoSeverity','hoHoursLeft','hoAsleep','cafLevel','cafDryHours','cafWithdraw','cafWithdrawing','cafLastDose','migActive','migAuraLeft','migChance','migSeverity','migHoursLeft','migSinceEnd','migMedsUsed','hemoOpen','hemoWarned','anIron','anDeficit','anLastIron','anTier','anLastCatch','anLastEndurance','artJoint','artStiffTarget','artCombatSet','glucose','diaFast','diaSlow','diaInsulin','diaMedMinutes','diaKetoHours','diaHaloIn','diaFumble','asthma','asthmaAttack','asthmaCoughIn','asthmaShownTier','mddSeverity','mddEpisode','mddHoursLeft','mddSinceEnd','mddOutside','mddSmokeTimer','mddFoodTimer','mddMedDays','mddMedStreak','mddWithdraw','gluten','glutenPending','glutenOnset','dryHours','withdrawing']);
  const rest=Object.entries(m).filter(([k])=>!shown.has(k)).sort();
  cards.push(card('All mod data', `<table>${Object.entries(m).sort().map(([k,v])=>`<tr><td>${k}</td><td>${fmt(v)}</td></tr>`).join('')}</table>`));
  cards.push(card('Log', `<pre>${arr(d.log).map(l=>l.text).join('\n')}</pre>`));
  cards.push(card('Raw telemetry', `<details><summary>show JSON</summary><pre>${JSON.stringify(d,null,1)}</pre></details>`,'wide'));
  document.getElementById('main').innerHTML=cards.join('');
  spark('c_glucose','mod.glucose',20,400,[[70,180,'rgba(91,191,122,.12)'],[250,400,'rgba(224,90,90,.10)'],[20,55,'rgba(224,90,90,.10)']]);
  spark('c_asthma','mod.asthma',0,1,[[0.9,1,'rgba(224,90,90,.12)'],[0.5,0.9,'rgba(224,176,74,.08)']]);
  spark('c_unhappy','stat.unhappiness',0,100); spark('c_gluten','mod.gluten',0,1);
  spark('c_vitality','mod.vitality',0,1,[[0.6,1,'rgba(91,191,122,.10)'],[0,0.4,'rgba(224,90,90,.10)']]);
  wireCmd();
}
let failures=0;
function setStatus(text,cls){ const el=document.getElementById('status'); el.textContent=text; el.className=cls; }
async function poll(){
  try{
    const r=await fetch('/data',{cache:'no-store'}); const d=await r.json(); failures=0;
    if(d && d._error){ setStatus('server error: '+d._error,'stale'); }
    else if(d && d.t){
      if(d.t!==lastT){ lastT=d.t; last=d; render(d); }
      if(d.paused) setStatus('paused'+(d._fresh?'':' (readout '+Math.round(d._ageSec)+' s old)'),'live');
      else if(d._fresh) setStatus('live','live');
      else setStatus('no data for '+Math.round(d._ageSec)+' s (game closed or not in a world)','stale');
    } else setStatus('waiting for the game','stale');
  }catch(e){ failures++; if(failures>=3) setStatus('dashboard server unreachable ('+e.message+')','stale'); }
  setTimeout(poll,500);
}
async function send(line){ if(!line) return; await fetch('/cmd',{method:'POST',body:line}); const i=document.getElementById('cmdin'); if(i){ i.value=''; } }
function wireCmd(){ const i=document.getElementById('cmdin'); if(!i||i.dataset.wired) return; i.dataset.wired=1; i.addEventListener('keydown',e=>{ if(e.key==='Enter') send(i.value.trim()); }); document.querySelectorAll('[data-cmd]').forEach(b=>b.onclick=()=>send(b.dataset.cmd)); }
poll();
</script>
<div id="cmdcard" class="card"><h2>Command</h2>
<div id="cmd"><input id="cmdin" placeholder="set glucose 40 | stat PANIC 100 | inject 2 | carbs 50 fast | mdd start 1 48 | episode charge | give DanTraits.InsulinPen | health 50 | weight 110"><button onclick="send(document.getElementById('cmdin').value.trim())">send</button></div>
<div class="groups">
<div class="group"><b>Vanilla</b><button data-cmd="stat PANIC 100">panic 100</button><button data-cmd="stat PANIC 0">panic 0</button><button data-cmd="stat ENDURANCE 0.1">endurance 10%</button><button data-cmd="stat ENDURANCE 1">endurance full</button><button data-cmd="stat FATIGUE 0.9">exhausted</button><button data-cmd="stat FATIGUE 0">rested</button><button data-cmd="stat STRESS 1">stress max</button><button data-cmd="stat UNHAPPINESS 90">miserable</button><button data-cmd="stat UNHAPPINESS 0">happy</button><button data-cmd="stat INTOXICATION 60">drunk</button><button data-cmd="stat INTOXICATION 0">sober</button><button data-cmd="stat PAIN 80">pain 80</button><button data-cmd="stat PAIN 0">no pain</button><button data-cmd="health 40">health 40</button><button data-cmd="health 100">heal</button><button data-cmd="weight 110">weight 110</button><button data-cmd="weight 75">weight 75</button></div>
<div class="group"><b>Diabetes</b><button data-cmd="set glucose 65">low 65</button><button data-cmd="set glucose 50">low 50</button><button data-cmd="set glucose 35">low 35</button><button data-cmd="set glucose 110">normal 110</button><button data-cmd="set glucose 200">high 200</button><button data-cmd="set glucose 300">high 300</button><button data-cmd="set glucose 450">high 450</button><button data-cmd="set diaKetoHours 24">keto day done</button><button data-cmd="set diaKetoHours 0">keto reset</button><button data-cmd="carbs 30 fast">+30 g fast (cola)</button><button data-cmd="carbs 100 slow">+100 g slow (loaf)</button><button data-cmd="inject 1">inject 1</button><button data-cmd="inject 4">inject 4</button><button data-cmd="set diaInsulin nil">clear insulin</button><button data-cmd="metformin">metformin</button><button data-cmd="set diaMedMinutes 0">metformin off</button><button data-cmd="give DanTraits.InsulinPen">give pen</button><button data-cmd="give DanTraits.GlucoseMeter">give meter</button><button data-cmd="give DanTraits.TestStrips">give strips</button><button data-cmd="give DanTraits.Metformin">give metformin</button></div>
<div class="group"><b>Asthma</b><button data-cmd="set asthma 0.3">tier 1 (30%)</button><button data-cmd="set asthma 0.55">tier 2 (55%)</button><button data-cmd="set asthma 0.8">tier 3 (80%)</button><button data-cmd="set asthma 0.95">attack (95%)</button><button data-cmd="set asthma 0">clear</button><button data-cmd="cough 10">cough</button><button data-cmd="cough 30">loud cough</button><button data-cmd="inhaler">inhaler</button><button data-cmd="give DanTraits.Inhaler">give inhaler</button></div>
<div class="group"><b>MDD</b><button data-cmd="mdd start 1 48">episode (sev 1, 48 h)</button><button data-cmd="mdd start 0.5 24">episode (sev 0.5, 24 h)</button><button data-cmd="mdd end">end episode</button><button data-cmd="set mddSinceEnd 48">refractory over</button><button data-cmd="antidep">antidepressant</button><button data-cmd="set mddMedStreak 14">streak 14 d</button><button data-cmd="set mddMedStreak 0">streak 0</button><button data-cmd="set mddWithdraw 4320">withdrawal</button><button data-cmd="set mddOutside 300">outdoorsy</button><button data-cmd="set mddOutside 0">shut in</button></div>
<div class="group"><b>Gluten</b><button data-cmd="gluten 33 now">slice, now</button><button data-cmd="gluten 99 now">loaf, now</button><button data-cmd="gluten 99">loaf (20 min onset)</button><button data-cmd="set gluten 1">full flare</button><button data-cmd="set gluten 0">clear</button></div>
<div class="group"><b>Dependent</b><button data-cmd="set dryHours 25">dry 25 h (craving)</button><button data-cmd="set dryHours 49">dry 49 h (pain)</button><button data-cmd="set dryHours 0">just drank</button></div>
<div class="group"><b>Hallucinations</b><button data-cmd="episode charge">phantom charge</button><button data-cmd="episode sound">phantom sound</button><button data-cmd="episode whisper">whisper</button><button data-cmd="episode thump">thump</button><button data-cmd="episode glass">glass</button><button data-cmd="episode footsteps">footsteps</button><button data-cmd="episode panic">panic bout</button></div>
<div class="group"><b>Vitality</b><button data-cmd="set vitality 0.1">run down</button><button data-cmd="set vitality 0.3">sluggish</button><button data-cmd="set vitality 0.5">neutral</button><button data-cmd="set vitality 0.7">fit</button><button data-cmd="set vitality 0.9">thriving</button><button data-cmd="set vitDiet 1">diet 1</button><button data-cmd="set vitDiet 0">diet 0</button><button data-cmd="set vitSleep 1">sleep 1</button><button data-cmd="set vitSleep 0">sleep 0</button><button data-cmd="set vitSleepDebt 0.9">slept badly</button><button data-cmd="set vitSleepDebt 0">slept fine</button><button data-cmd="stat HUNGER 0.8">starving</button><button data-cmd="stat HUNGER 0">fed</button></div>
<div class="group"><b>Brittle / Fumbler</b><button data-cmd="fracture">fracture a limb</button><button data-cmd="drop">drop weapon</button></div>
</div></div></div>
</body></html>
"""


class Handler(BaseHTTPRequestHandler):
    folder = None
    last_good = {}

    def log_message(self, *a):  # quiet
        pass

    def _send(self, code, body, ctype="application/json"):
        data = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", ctype + "; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path.startswith("/data"):
            try:
                self._send(200, json.dumps(self.read_data()))
            except Exception as e:  # never drop the connection: tell the page what broke
                import traceback
                traceback.print_exc()
                self._send(200, json.dumps({"_error": "%s: %s" % (type(e).__name__, e)}))
        else:
            self._send(200, HTML, "text/html")

    def read_data(self):
        import time
        path = os.path.join(self.folder, TELEMETRY)
        data = Handler.last_good
        try:
            with open(path, "r", encoding="utf-8") as f:
                text = f.read()
            if text.strip():
                data = json.loads(text)
                Handler.last_good = data
        except (OSError, ValueError):
            pass  # missing, locked by the game, or mid-write: serve the last good one
        try:
            age = time.time() - os.path.getmtime(path)
        except OSError:
            age = 1e9
        out = dict(data)
        out["_ageSec"] = age
        out["_fresh"] = age < 3
        return out

    def do_POST(self):
        if self.path.startswith("/cmd"):
            n = int(self.headers.get("Content-Length", "0"))
            line = self.rfile.read(n).decode("utf-8").strip()
            if line:
                with open(os.path.join(self.folder, COMMANDS), "a", encoding="utf-8") as f:
                    f.write(line + "\n")
            self._send(200, "{}")
        else:
            self._send(404, "{}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=os.path.join(os.path.expanduser("~"), "Zomboid", "Lua"))
    ap.add_argument("--port", type=int, default=PORT)
    ap.add_argument("--no-browser", action="store_true")
    a = ap.parse_args()
    Handler.folder = a.dir
    os.makedirs(a.dir, exist_ok=True)
    server = ThreadingHTTPServer(("127.0.0.1", a.port), Handler)
    url = "http://127.0.0.1:%d/" % a.port
    print("Project Zomboid Vitality Project dashboard: %s   (folder: %s)   Ctrl+C to stop" % (url, a.dir))
    if not a.no_browser:
        threading.Timer(0.5, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
