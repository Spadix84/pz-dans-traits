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
.wide{grid-column:1/-1}.beside{grid-column:2/-1}@media(max-width:760px){.beside{grid-column:auto}}
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
  // what moved each stat
  cards.push(attribCard(d));
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
  // alcoholic (trait id dependent); the meter is kept for everyone
  if(has('dependent')&&m.dryHours!=null){ cards.push(card('Alcoholic', `<div class="big ${m.withdrawing?'bad':'ok'}">${fmt(m.dryHours,1)}<span class="dim" style="font-size:13px"> h dry</span></div>` + row('stage',['none','craving','shakes','delirium'][m.alcStage||0]) + row('strength / shakes %',`${fmt(m.alcW,2)} / ${fmt(m.alcShakes,1)}`) + row('alcoholism',fmt(m.depTolerance,2)) + bar(m.depTolerance,1,'var(--warn)') + row('sober h (720 cures)',fmt(m.alcSoberHours,1)))); }
  else if(m.depTolerance>0||m.alcEx){ cards.push(card('Alcoholism', `<div class="big ${m.depTolerance>=0.2?'warn':'ok'}">${fmt(m.depTolerance,2)}<span class="dim" style="font-size:13px"> / 0.30 to gain</span></div>` + bar(m.depTolerance,0.3,'var(--warn)') + row('today',fmt(m.alcDayGain,3)) + row('ex-alcoholic',fmt(m.alcEx)))); }
  // hangover (everyone)
  if(m.hoLoad!=null){ const hs=m.hoActive?(m.hoSeverity||0)*Math.min(1,(m.hoHoursLeft||0)/2):0;
    cards.push(card('Hangover', `<div class="big ${m.hoActive?'bad':m.hoPending?'warn':'ok'}">${m.hoActive?'HUNGOVER':m.hoPending?'waiting to wake':m.hoDrinking?'drinking':'clear'}</div>` + row('load (drunk-hours)',fmt(m.hoLoad,2)) + bar(m.hoLoad,3,'var(--warn)') + row('severity',fmt(m.hoSeverity,2)) + row('hours left',fmt(m.hoHoursLeft,1)) + row('strength now',fmt(hs,2)))); }
  // caffeine
  if(has('caffeine')&&m.cafLevel!=null){ cards.push(card('Caffeine Dependent', `<div class="big ${(m.cafWithdraw||0)>0?'bad':'ok'}">${Math.round(m.cafLevel)}<span class="dim" style="font-size:13px"> caffeine (60 = sated)</span></div>` + bar(m.cafLevel,400) + row('hours dry',fmt(m.cafDryHours,1)) + row('withdrawal',fmt(m.cafWithdraw,2)) + bar(m.cafWithdraw,1,'var(--bad)') + row('last dose',fmt(m.cafLastDose)))); }
  // migraine
  // smoker (vanilla trait): anyone who has ever smoked carries the meter
  if(m.nicMeter!=null){ const sm=arr(d.traits).some(t=>t.toLowerCase()==='base:smoker'); const w=m.nicWithdraw||0;
    cards.push(card(sm?'Smoker':'Nicotine', `<div class="big ${w>=0.5?'bad':w>0?'warn':'ok'}">${sm?Math.round(w*100)+'<span class="dim" style="font-size:13px"> % craving</span>':fmt(m.nicMeter,2)+'<span class="dim" style="font-size:13px"> / 0.30 to gain</span>'}</div>` + (sm?bar(w,1,'var(--bad)'):'') + row('nicotine meter',fmt(m.nicMeter,2)) + bar(m.nicMeter,1,'var(--warn)') + row('lungs',fmt(m.nicLungs,3)) + bar(m.nicLungs,1,'var(--warn)') + row('hours without tobacco (504 cures)',fmt(m.nicDryHours,1)) + row('hours since smoked',fmt(m.nicSmokeHours,1)) + row('today',fmt(m.nicDayGain,3)) + row('caffeine clearance x',fmt(1+(m.nicInduce||0),2)) + row('coughs',fmt(m.nicCoughs)) + row('ex-smoker / cue min',`${fmt(m.nicEx)} / ${fmt(m.nicCueMin)}`))); }
  if(has('migraine')){ cards.push(card('Migraines', `<div class="big ${m.migActive?'bad':m.migAuraLeft?'warn':'ok'}">${m.migActive?'MIGRAINE':m.migAuraLeft?'AURA':'clear'}</div>` + row('chance / 10 min',fmt(m.migChance,2)+' %') + row('severity',fmt(m.migSeverity,2)) + row('hours left',fmt(m.migHoursLeft,1)) + row('aura left (h)',fmt(m.migAuraLeft,2)) + row('hours since end',fmt(m.migSinceEnd,1)) + row('painkillers used',fmt(m.migMedsUsed)))); }
  // hemophilia
  // blood (everyone): volume drives the tiers, red cells the slow weakness after
  if(m.bloodVol!=null){ const lost=1-m.bloodVol, tier=m.bloodTier||0, names=['fine','pale','light-headed','SHOCK','BLEEDING OUT'];
    cards.push(card('Blood', `<div class="big ${tier>=3?'bad':tier>=1?'warn':'ok'}">${Math.round(m.bloodVol*100)}<span class="dim" style="font-size:13px"> % volume, ${names[tier]}</span></div>${bar(m.bloodVol,1,tier>=2?'var(--bad)':'var(--ok)')}`
      + row('red cells',Math.round((m.bloodCells||0)*100)+' %') + bar(m.bloodCells,1,'var(--warn)') + row('weakness',fmt(m.bloodWeak,2))
      + row('losing / min',fmt((m.bloodLossMin||0)*100,3)+' %') + row('bleeding from',m.bloodSources||'-') + row('vanilla bleed refunded',fmt(m.bloodRefunded,2))
      + (m.bloodDebug?row('health / min',fmt(m.bloodDbgHealthMin,3))+row('refunded / min',fmt(m.bloodDbgRefundMin,3))+`<div class="dim" style="font-size:12px">${m.bloodDbgParts||''}</div>`:''))); }
  // infection (everyone): per-part level, whole-body score, antibiotics
  if(m.infS!=null){ const st=m.infStage||0, names=['clear','contaminated','local','FEVER','SEPSIS'];
    const parts=Object.entries(m.infParts||{}).map(([k,v])=>`${k} ${v.inc!=null?'incubating '+fmt(v.inc/60,1)+' h':'L '+fmt(v.L,2)}${v.clean?' (cleaned)':''}`).join(', ')||'-';
    cards.push(card('Infection', `<div class="big ${st>=3?'bad':st>=1?'warn':'ok'}">${names[st]}</div>` + row('worst level (0-10)',fmt(m.infMaxL,2)) + row('whole body',fmt(m.infS,3)) + bar(m.infS,1,'var(--bad)')
      + row('fever',fmt(m.infFever,2)) + row('body temperature',fmt(m.infBodyTemp,2)+' C') + row('antibiotic level (0.5+ works)',fmt(m.infAbx,2)) + row('doses this course',fmt(m.infDoses,0)+(m.infUnfinished?' (unfinished, off '+fmt(m.infOffH,1)+' h)':''))
      + row('inside (relapse)',fmt(m.infFocus||0,2)) + `<div class="dim" style="font-size:12px">${parts}</div>`)); }
  if(has('hemophilia')){ cards.push(card('Hemophilia', `<div class="big ${(m.hemoOpen||0)>0?'bad':'ok'}">${fmt(m.hemoOpen||0)}<span class="dim" style="font-size:13px"> open bleed(s)</span></div>`)); }
  // anaemic
  if(has('anemia')&&m.anIron!=null){ cards.push(card('Anaemic', `<div class="big ${(m.anDeficit||0)>=0.5?'bad':(m.anDeficit||0)>0?'warn':'ok'}">${Math.round(m.anIron*100)}<span class="dim" style="font-size:13px"> % iron (40 = enough)</span></div>` + bar(m.anIron,1,(m.anDeficit||0)>0?'var(--warn)':'var(--acc)') + row('deficit',fmt(m.anDeficit,2)) + row('last iron from',fmt(m.anLastIron)))); }
  // arthritis
  if(has('arthritis')){ cards.push(card('Arthritis', `<div class="big ${(m.artJoint||0)>=0.5?'bad':(m.artJoint||0)>0?'warn':'ok'}">${Math.round((m.artJoint||0)*100)}<span class="dim" style="font-size:13px"> % flare</span></div>` + bar(m.artJoint,1,'var(--warn)') + row('stiffness floor',fmt(m.artStiffTarget,1)) + row('combat speed set',fmt(m.artCombatSet,2)))); }
  // everything else in mod data
  const shown=new Set(['infBodyTemp','infParts','infS','infAbx','infDoses','infMaxL','infStage','infFever','infSickness','infActive','infUnfinished','infOffH','infFocus','bloodVol','bloodCells','bloodTier','bloodWeak','bloodLossMin','bloodSources','bloodRefunded','bloodLastEndurance','bloodDebug','bloodDbgParts','bloodDbgHealth','bloodDbgHealthMin','bloodDbgRefundMin','bloodDbgRefundLast','depTolerance','alcStage','alcW','alcShakes','alcSoberHours','alcDayGain','alcEx','hoLoad','hoActive','hoPending','hoDrinking','hoSeverity','hoHoursLeft','hoAsleep','cafLevel','cafDryHours','cafWithdraw','cafWithdrawing','cafLastDose','migActive','migAuraLeft','migChance','migSeverity','migHoursLeft','migSinceEnd','migMedsUsed','hemoOpen','hemoWarned','anIron','anDeficit','anLastIron','anTier','anLastCatch','anLastEndurance','artJoint','artStiffTarget','artCombatSet','glucose','diaFast','diaSlow','diaInsulin','diaMedMinutes','diaKetoHours','diaHaloIn','diaFumble','asthma','asthmaAttack','asthmaCoughIn','asthmaShownTier','mddSeverity','mddEpisode','mddHoursLeft','mddSinceEnd','mddOutside','mddSmokeTimer','mddFoodTimer','mddMedDays','mddMedStreak','mddWithdraw','gluten','glutenPending','glutenOnset','dryHours','withdrawing']);
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
// Attribution: which trait moved which stat (DanTraits_Attrib.lua). Each
// wrapped handler's before/after difference is credited to its file; the
// rest of the net change is the game, other mods or actions (eating, reading).
const AT={win:0,frozen:null,autoSent:false,userOff:false,open:{unhappiness:true,stress:true}};
// stats where going up is good, for colouring
const UP_GOOD=new Set(['endurance','health']);
// where vanilla usually gets it from (moodles on the right say which apply now)
const VANILLA={unhappiness:'boredom, wet / uncomfortable, pain, sickness, food eaten (stale, rotten, bland), dirty / bloody clothes, smoker craving',
  stress:'zombies nearby, panic, pain, injuries, sickness, smoker craving',boredom:'idle or indoors a long time; TV, radio, books and outdoors lower it',
  panic:'zombies in view, being grabbed, low light with zombies near',fatigue:'time awake, exertion; sleep lowers it',endurance:'running, fighting, heavy load; resting restores it',
  pain:'injuries, fractures, burns, sickness',hunger:'time, exertion',thirst:'time, exertion, heat, alcohol',food_sickness:'bad food, rotten food',
  sickness:'infection, cold, food poisoning',health:'injuries, sickness, starvation, dehydration',wetness:'rain, swimming; dries over time'};
function atFmt(v){ if(v==null) return '-'; if(Math.abs(v)<1e-6) return '0'; const a=Math.abs(v); const s=a>=10?v.toFixed(1):a>=1?v.toFixed(2):a>=0.01?v.toFixed(3):v.toExponential(1); return (v>0?'+':'')+s; }
function atCls(stat,v){ if(Math.abs(v)<1e-6) return 'dim'; const bad=UP_GOOD.has(stat)?v<0:v>0; return bad?'bad':'ok'; }
function atToggle(stat){ AT.open[stat]=!AT.open[stat]; if(last) render(last); }
function atWin(i){ AT.win=i; if(last) render(last); }
function atFreeze(){ AT.frozen=AT.frozen?null:(last&&last.attrib)||null; if(last) render(last); }
function atPower(on){ AT.userOff=!on; send('attrib '+(on?'on':'off')); }
function attribCard(d){
  const live=d.attrib||{}, a=AT.frozen||live, mood=d.moodles||{};
  if(live.enabled===false&&!AT.autoSent&&!AT.userOff){ AT.autoSent=true; send('attrib on'); }
  const moods=Object.entries(mood).sort((x,y)=>y[1]-x[1]).map(([k,v])=>`<span class="chip">${k.replace(/_/g,' ')} ${v}</span>`).join(' ')||'<span class="dim">none</span>';
  const ctl=`<div style="display:flex;gap:6px;flex-wrap:wrap;align-items:center;margin-bottom:8px">`
    + arr(a.windows).map((w,i)=>`<button onclick="atWin(${i})" style="${i===AT.win?'border-color:var(--acc)':''}">${w.name}</button>`).join('')
    + `<button onclick="atFreeze()" style="${AT.frozen?'border-color:var(--warn);color:var(--warn)':''}">${AT.frozen?'frozen - click for live':'freeze'}</button>`
    + `<button onclick="send('attrib reset')">reset</button>`
    + (live.enabled?`<button onclick="atPower(false)">turn off</button>`:`<button onclick="atPower(true)">turn on</button>`)
    + `<span class="dim" style="margin-left:auto">moodles now: ${moods}</span></div>`;
  if(!a.enabled&&!AT.frozen) return card('What is moving each stat',ctl+`<div class="dim">attribution is off${live.enabled===undefined?' (the game has not loaded DanTraits_Attrib.lua; deploy and restart)':''}</div>`,'beside');
  const w=arr(a.windows)[AT.win]||arr(a.windows)[0];
  if(!w) return card('What is moving each stat',ctl+'<div class="dim">collecting...</div>','beside');
  const total=w.total||{}, src=w.sources||{};
  const stats=new Set(Object.keys(total)); for(const r of Object.values(src)) for(const k of Object.keys(r)) stats.add(k);
  const order=['unhappiness','stress','boredom','panic','fatigue','endurance','pain','health','hunger','thirst','food_sickness','sickness','intoxication','wetness'];
  const rank=k=>{ const n=order.indexOf(k); return n<0?99:n; }, list=[...stats].sort((x,y)=>rank(x)-rank(y));
  const rows=list.map(stat=>{
    const net=total[stat]||0; let credited=0; const parts=[];
    for(const [label,r] of Object.entries(src)) if(r[stat]!=null){ credited+=r[stat]; parts.push([label,r[stat]]); }
    const rest=net-credited; if(Math.abs(rest)>1e-6) parts.push(['game / other mods / actions',rest,true]);
    parts.sort((x,y)=>Math.abs(y[1])-Math.abs(x[1]));
    const quiet=Math.abs(net)<1e-6&&parts.every(p=>Math.abs(p[1])<1e-6);
    const open=AT.open[stat];
    const detail=open?`<table style="margin:2px 0 8px">${parts.map(p=>`<tr><td>${p[2]?'<i>'+p[0]+'</i>':p[0]}</td><td class="${atCls(stat,p[1])}">${atFmt(p[1])}</td></tr>`).join('')||'<tr><td class="dim">nothing</td><td></td></tr>'}</table>`
      +(VANILLA[stat]?`<div class="dim" style="font-size:12px;margin:-4px 0 8px">vanilla usually: ${VANILLA[stat]}</div>`:''):'';
    return `<div class="row" style="cursor:pointer${quiet?';opacity:.5':''}" onclick="atToggle('${stat}')"><span>${open?'&#9662;':'&#9656;'} ${stat.replace(/_/g,' ')}</span><span class="${atCls(stat,net)}">net ${atFmt(net)}${parts.length?' <span class="dim">('+parts.length+' source'+(parts.length>1?'s':'')+')</span>':''}</span></div>`+detail;
  }).join('');
  const span=`<div class="dim" style="font-size:12px;margin-bottom:6px">${w.name}: covering the last ${w.span} game minute(s). Numbers are net change over the window in the stat's own units; click a stat to open it.</div>`;
  return card('What is moving each stat'+(AT.frozen?' <span class="warn">(frozen)</span>':''),ctl+span+rows,'beside');
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
<div class="group"><b>Alcoholic</b><button data-cmd="set dryHours 25">dry 25 h (craving)</button><button data-cmd="set dryHours 49">dry 49 h (pain)</button><button data-cmd="set dryHours 0">just drank</button><button data-cmd="set depTolerance 1">meter 1 (delirium-capable)</button><button data-cmd="set dryHours 40">dry 40 h (delirium at meter 1)</button></div>
<div class="group"><b>Hallucinations</b><button data-cmd="episode charge">phantom charge</button><button data-cmd="episode sound">phantom sound</button><button data-cmd="episode whisper">whisper</button><button data-cmd="episode thump">thump</button><button data-cmd="episode glass">glass</button><button data-cmd="episode footsteps">footsteps</button><button data-cmd="episode panic">panic bout</button></div>
<div class="group"><b>Vitality</b><button data-cmd="set vitality 0.1">run down</button><button data-cmd="set vitality 0.3">sluggish</button><button data-cmd="set vitality 0.5">neutral</button><button data-cmd="set vitality 0.7">fit</button><button data-cmd="set vitality 0.9">thriving</button><button data-cmd="set vitDiet 1">diet 1</button><button data-cmd="set vitDiet 0">diet 0</button><button data-cmd="set vitSleep 1">sleep 1</button><button data-cmd="set vitSleep 0">sleep 0</button><button data-cmd="set vitSleepDebt 0.9">slept badly</button><button data-cmd="set vitSleepDebt 0">slept fine</button><button data-cmd="stat HUNGER 0.8">starving</button><button data-cmd="stat HUNGER 0">fed</button></div>
<div class="group"><b>Brittle / Fumbler</b><button data-cmd="fracture">fracture a limb</button><button data-cmd="drop">drop weapon</button></div>
</div></div></div>
</body></html>
<div class="group"><b>Infection</b><button data-cmd="contaminate forearm_l 5">contaminate forearm (5 min)</button><button data-cmd="infect forearm_l 3">local, L3</button><button data-cmd="infect forearm_l 7">spreading, L7</button><button data-cmd="sepsis 0.3">fever (0.3)</button><button data-cmd="sepsis 0.7">sepsis (0.7)</button><button data-cmd="sepsis 0.9">septic shock (0.9)</button><button data-cmd="antibiotic">antibiotic dose</button><button data-cmd="infection clear">clear</button></div>
<div class="group"><b>Blood</b><button data-cmd="blood 0.8">lost 20% (pale)</button><button data-cmd="blood 0.65">lost 35% (light-headed)</button><button data-cmd="blood 0.58">lost 42% (shock)</button><button data-cmd="blood 1 0.6">volume back, cells 60%</button><button data-cmd="blood reset">full</button><button data-cmd="blood debug on">debug on</button><button data-cmd="blood debug off">debug off</button><button data-cmd="wound forearm_l glass">deep + glass, forearm</button><button data-cmd="wound thigh_l deep">deep, thigh</button><button data-cmd="wound hand_r cut">cut, hand</button><button data-cmd="wound neck deep">deep, neck</button></div>
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
