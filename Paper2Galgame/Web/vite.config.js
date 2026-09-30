import {defineConfig} from 'vite';
// A single classic IIFE avoids file:// ES-module CORS in WKWebView.
export default defineConfig({base:'./',define:{'process.env.NODE_ENV':'"production"'},build:{lib:{entry:'adapter.tsx',name:'LumapPaper2Galgame',formats:['iife'],fileName:()=> 'runtime.js'},sourcemap:false,minify:true,rollupOptions:{output:{inlineDynamicImports:true}}}});
