import type {NextConfig} from 'next';
import {transportSecurity} from './src/lib/security-policy';
const hsts=transportSecurity(process.env.APP_ORIGIN??'http://127.0.0.1:3000',process.env.NODE_ENV==='production');
const config: NextConfig = {
  poweredByHeader:false,
  logging:{serverFunctions:false,incomingRequests:false},
  async headers() { return [{source:'/:path*',headers:[
    {key:'X-Content-Type-Options',value:'nosniff'},
    {key:'X-Frame-Options',value:'DENY'},
    {key:'Referrer-Policy',value:'no-referrer'},
    {key:'Cache-Control',value:'private, no-store'},
    {key:'Permissions-Policy',value:'camera=(), microphone=(), geolocation=()'},
    ...(hsts?[{key:'Strict-Transport-Security',value:hsts}]:[])
  ]}]; }
};
export default config;

