// SPDX-License-Identifier: BSD-3-Clause
// Gauge artwork separately dedicated under CC0-1.0.
// Original gauge artwork; static picture: ../assets/fuel-gauge.svg.
// Artwork license: ../licenses/CC0-1.0.txt; code license: ../LICENSE.
// Provenance: ../3RDPARTYLICENSE.txt.
import React from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import Svg, { Path, Line, Circle, Text as SvgText } from 'react-native-svg';
export default function FuelGauge({value,onChange}:{value:number|null;onChange:(value:number)=>void}) {
 const angle = Math.PI * (1 - (value ?? 0)/100);
 return <View><Svg width="100%" height={155} viewBox="0 0 300 165" accessibilityLabel={`Fuel gauge: ${value === null ? 'not selected' : value+' percent'}`}>
 <Path d="M 35 140 A 115 115 0 0 1 265 140" fill="none" stroke="#e2e9e7" strokeWidth={20}/>
 <Path d="M 35 140 A 115 115 0 0 1 57 72" fill="none" stroke="#e7a36a" strokeWidth={20}/>
 {[0,25,50,75,100].map(v=>{const a=Math.PI*(1-v/100);return <SvgText key={v} x={150+94*Math.cos(a)} y={145-94*Math.sin(a)} textAnchor="middle" fontSize={12} fill="#58706b">{v===0?'E':v===100?'F':v/100}</SvgText>})}
 {value!==null&&<Line x1={150} y1={140} x2={150+80*Math.cos(angle)} y2={140-80*Math.sin(angle)} stroke="#0f6256" strokeWidth={4} strokeLinecap="round"/>}<Circle cx={150} cy={140} r={8} fill="#0f6256"/>
 </Svg><Text style={s.value}>{value === null ? 'Select fuel level' : `${value}%`}</Text>
 <View style={s.options}>{Array.from({length:11},(_,i)=>i*10).map(v=><Pressable key={v} accessibilityRole="radio" accessibilityState={{checked:value===v}} accessibilityLabel={`${v} percent fuel`} onPress={()=>onChange(v)} style={[s.option,value===v&&s.selected]}><Text style={{color:value===v?'white':'#214d45'}}>{v}</Text></Pressable>)}</View>
 {value!==null&&value<=20&&<Text style={s.warning}>Low fuel — refuel before departure.</Text>}</View>
}
const s=StyleSheet.create({value:{textAlign:'center',fontSize:23,fontWeight:'700',color:'#153e36',marginBottom:16},options:{flexDirection:'row',flexWrap:'wrap',gap:8},option:{minWidth:44,minHeight:44,borderRadius:12,backgroundColor:'#edf3f0',alignItems:'center',justifyContent:'center'},selected:{backgroundColor:'#0f6256'},warning:{color:'#98501d',marginTop:14}});
