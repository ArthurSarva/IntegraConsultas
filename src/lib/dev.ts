import 'server-only';
import {redirect} from 'next/navigation';
import {authorized,workspace} from '@/lib/identity';
export async function dev(){const result=await authorized();if(!result.profile.is_dev)redirect('/inicio');return result;}
export async function devWorkspace(){const result=await workspace();if(!result.profile.is_dev)redirect('/inicio');return result;}

