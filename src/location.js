import {Capacitor} from '@capacitor/core';
import {Geolocation} from '@capacitor/geolocation';
import {createNativeLocationProvider,locationError} from './location-provider.js';
export {temporaryLocationError} from './location-provider.js';
const native=createNativeLocationProvider(Geolocation);
export const nativeLocation=()=>Capacitor.isNativePlatform();
export const hasLocation=()=>nativeLocation()?Capacitor.isPluginAvailable('Geolocation'):Boolean(navigator.geolocation);
export async function devicePosition(){
 if(nativeLocation())return native.position();
 return new Promise((resolve,reject)=>navigator.geolocation.getCurrentPosition(resolve,error=>reject(locationError(error)),{enableHighAccuracy:true,timeout:45000,maximumAge:10000}));
}
export async function watchDevicePosition(success,failure){
 if(nativeLocation())return native.watch(success,failure);
 return navigator.geolocation.watchPosition(success,error=>failure(locationError(error)),{enableHighAccuracy:true,maximumAge:5000,timeout:45000});
}
export async function clearDeviceWatch(id){if(nativeLocation())await native.clear(id);else navigator.geolocation.clearWatch(id);}
export const publicOrigin=()=>nativeLocation()?'https://familytrack-pro.coolbrush513.chatgpt.site':location.origin;
