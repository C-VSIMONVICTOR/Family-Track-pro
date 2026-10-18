import {Capacitor} from '@capacitor/core';
import {Geolocation} from '@capacitor/geolocation';
export const hasLocation=()=>Capacitor.isNativePlatform()||Boolean(navigator.geolocation);
export async function devicePosition(){
 if(Capacitor.isNativePlatform()){await Geolocation.requestPermissions();return Geolocation.getCurrentPosition({enableHighAccuracy:true,timeout:15000,maximumAge:0});}
 return new Promise((resolve,reject)=>navigator.geolocation.getCurrentPosition(resolve,()=>reject(Error('Location access was not allowed. Choose Allow in your device settings, then try again.')),{enableHighAccuracy:true,timeout:15000,maximumAge:0}));
}
export async function watchDevicePosition(success,failure){
 if(Capacitor.isNativePlatform())return Geolocation.watchPosition({enableHighAccuracy:true,timeout:20000,minimumUpdateInterval:10000},(position,error)=>error?failure(error):position&&success(position));
 return navigator.geolocation.watchPosition(success,failure,{enableHighAccuracy:true,maximumAge:5000,timeout:20000});
}
export async function clearDeviceWatch(id){if(Capacitor.isNativePlatform())await Geolocation.clearWatch({id});else navigator.geolocation.clearWatch(id);}
export const publicOrigin=()=>Capacitor.isNativePlatform()?'https://familytrack-pro.coolbrush513.chatgpt.site':location.origin;
