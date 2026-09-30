// Lumap-owned host. The GameScreen module is fetched and patched locally by the installer.
import React, {useState,useEffect} from 'react';
import {createRoot} from 'react-dom/client';
import {GameScreen} from './upstream/components/GameScreen';
type State={sessionID:string;title:string;script:Array<{speaker:string;text:string;emotion:string;note?:string}>;position:number;sprites:Record<string,string>;background?:string};
declare global{interface Window{lumapPaper2GalgameLoad?:(state:State)=>void;lumapPaperSprites?:Record<string,string>;webkit?:{messageHandlers?:{paper2galgame?:{postMessage:(value:unknown)=>void}}}}}
function post(action:string,payload:unknown={}){window.webkit?.messageHandlers?.paper2galgame?.postMessage({action,payload});}
function App(){const [state,setState]=useState<State>();const [position,setPosition]=useState(0);window.lumapPaper2GalgameLoad=(next)=>{window.lumapPaperSprites=next.sprites;setState(next);setPosition(next.position);};useEffect(()=>{post('ready');},[]);
if(!state)return <div className="ready"><h1>Paper2Galgame</h1><p>Your sourced lesson becomes an interactive story.</p></div>;
return <main className="stage">{state.background&&<img className="stage-bg" alt="" src={state.background}/>}<div className="chapter-counter">PAPER2GALGAME · {position+1} / {state.script.length}</div><GameScreen key={state.sessionID} script={state.script as any} title={state.title} startIndex={state.position} onPosition={(index:number)=>{setPosition(index);post('progress',{sessionID:state.sessionID,position:index});}} onExit={()=>post('exit',{sessionID:state.sessionID})}/></main>}
createRoot(document.getElementById('root')!).render(<App/>);
