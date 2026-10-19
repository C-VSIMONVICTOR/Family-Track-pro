// Native adapter is injected so Android error/permission behavior can be tested.
export function locationError(error){
 const code=String(error?.code||'');
 let message=error?.message||'Could not get your location. Please try again.';
 if(code==='OS-PLUG-GLOC-0003'||error?.code===1)message='Location permission is off. Open Android Settings → Apps → FamilyTrack Pro → Permissions → Location, choose Allow only while using the app, then try again.';
 else if(['OS-PLUG-GLOC-0007','OS-PLUG-GLOC-0009','OS-PLUG-GLOC-0017'].includes(code))message='Turn on Location in your phone’s quick settings, then tap Share my location again. Keep mobile data or Wi-Fi on for a faster fix.';
 else if(code==='OS-PLUG-GLOC-0010'||error?.code===3)message='Your phone is taking longer to find a location. Move near a window or outdoors, keep Location and internet on, then try again.';
 else if(['OS-PLUG-GLOC-0014','OS-PLUG-GLOC-0015','OS-PLUG-GLOC-0016'].includes(code))message='Android could not start its location service. Turn on Location and Wi-Fi/mobile data, check Google Play services, then try again.';
 const result=new Error(message+(code?` (Location: ${code})`:''));result.code=error?.code;return result;
}
export const temporaryLocationError=error=>['OS-PLUG-GLOC-0002','OS-PLUG-GLOC-0010'].includes(String(error?.code))||[2,3].includes(error?.code);
export function createNativeLocationProvider(plugin,timers={setTimeout,clearTimeout}){
 const watches=new Map();let sequence=0;
 let precise=true;
 async function options(){
  // checkPermissions itself throws when the phone's Location switch is off.
  // Let getCurrentPosition handle that state and Android's resolution prompt.
  try{const status=await plugin.checkPermissions();precise=status.location==='granted'||status.coarseLocation!=='granted';}catch{precise=true;}
  return {enableHighAccuracy:precise,timeout:45000,maximumAge:10000,enableLocationFallback:true};
 }
 return {
  async position(){
   const settings=await options();
   try{return await plugin.getCurrentPosition(settings);}catch(error){
    if(String(error?.code)==='OS-PLUG-GLOC-0010'){
     try{return await plugin.getCurrentPosition({...settings,enableHighAccuracy:false,timeout:30000});}catch(retry){throw locationError(retry);}
    }
    throw locationError(error);
   }
  },
  async watch(success,failure){
   // Some Android plugin errors release a watch callback permanently. Use
   // sequential foreground fixes instead, so a timeout cannot silently end it.
   const id='native-location-'+(++sequence), watch={active:true,timer:null};watches.set(id,watch);
   const next=async()=>{
    if(!watch.active)return;
    try{const position=await plugin.getCurrentPosition({...await options(),timeout:30000});if(watch.active)success(position);}
    catch(error){if(watch.active){const mapped=locationError(error);failure(mapped);if(!temporaryLocationError(mapped)){watch.active=false;watches.delete(id);}}}
    if(watch.active)watch.timer=timers.setTimeout(next,10000);
   };
   watch.timer=timers.setTimeout(next,10000);return id;
  },
  clear(id){const watch=watches.get(id);if(watch){watch.active=false;timers.clearTimeout(watch.timer);watches.delete(id);}}

 };
}
