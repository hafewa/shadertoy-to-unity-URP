﻿Shader "UmutBebek/URP/ShaderToy/Playing marble MtX3Ws"
{
    Properties
    {
        _Channel0("Channel0 (RGB)", Cube) = "" {}
        _Channel1("Channel1 (RGB)", 2D) = "" {}
        _Channel2("Channel2 (RGB)", 2D) = "" {}
        _Channel3("Channel3 (RGB)", 2D) = "" {}
        [HideInInspector]iMouse("Mouse", Vector) = (0,0,0,0)

        zoom("zoom", float) = 1.

    }

        SubShader
        {
            // With SRP we introduce a new "RenderPipeline" tag in Subshader. This allows to create shaders
            // that can match multiple render pipelines. If a RenderPipeline tag is not set it will match
            // any render pipeline. In case you want your subshader to only run in LWRP set the tag to
            // "UniversalRenderPipeline"
            Tags{"RenderType" = "Transparent" "RenderPipeline" = "UniversalRenderPipeline" "IgnoreProjector" = "True"}
            LOD 300

            // ------------------------------------------------------------------
            // Forward pass. Shades GI, emission, fog and all lights in a single pass.
            // Compared to Builtin pipeline forward renderer, LWRP forward renderer will
            // render a scene with multiple lights with less drawcalls and less overdraw.
            Pass
            {
                // "Lightmode" tag must be "UniversalForward" or not be defined in order for
                // to render objects.
                Name "StandardLit"
                //Tags{"LightMode" = "UniversalForward"}

                //Blend[_SrcBlend][_DstBlend]
                //ZWrite Off ZTest Always
                //ZWrite[_ZWrite]
                //Cull[_Cull]

                HLSLPROGRAM
            // Required to compile gles 2.0 with standard SRP library
            // All shaders must be compiled with HLSLcc and currently only gles is not using HLSLcc by default
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            //do not add LitInput, it has already BaseMap etc. definitions, we do not need them (manually described below)
            //#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"

            TEXTURECUBE(_Channel0);
            SAMPLER(sampler_Channel0);
            float4 _Channel1_ST;
            TEXTURE2D(_Channel1);       SAMPLER(sampler_Channel1);
            float4 _Channel2_ST;
            TEXTURE2D(_Channel2);       SAMPLER(sampler_Channel2);
            float4 _Channel3_ST;
            TEXTURE2D(_Channel3);       SAMPLER(sampler_Channel3);

            float4 iMouse;
            float zoom;


            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float2 uv                       : TEXCOORD0;
                float4 positionCS               : SV_POSITION;
                float4 screenPos                : TEXCOORD1;
            };

            Varyings LitPassVertex(Attributes input)
            {
                Varyings output;

                // VertexPositionInputs contains position in multiple spaces (world, view, homogeneous clip space)
                // Our compiler will strip all unused references (say you don't use view space).
                // Therefore there is more flexibility at no additional cost with this struct.
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

                // TRANSFORM_TEX is the same as the old shader library.
                output.uv = TRANSFORM_TEX(input.uv, _Channel1);
                // We just use the homogeneous clip position from the vertex input
                output.positionCS = vertexInput.positionCS;
                output.screenPos = ComputeScreenPos(vertexInput.positionCS);
                return output;
            }

            #define FLT_MAX 3.402823466e+38
            #define FLT_MIN 1.175494351e-38
            #define DBL_MAX 1.7976931348623158e+308
            #define DBL_MIN 2.2250738585072014e-308

             #define iTimeDelta unity_DeltaTime.x
            // float;

            #define iFrame ((int)(_Time.y / iTimeDelta))
            // int;

           #define clamp(x,minVal,maxVal) min(max(x, minVal), maxVal)

           float mod(float a, float b)
           {
               return a - floor(a / b) * b;
           }
           float2 mod(float2 a, float2 b)
           {
               return a - floor(a / b) * b;
           }
           float3 mod(float3 a, float3 b)
           {
               return a - floor(a / b) * b;
           }
           float4 mod(float4 a, float4 b)
           {
               return a - floor(a / b) * b;
           }

           float4 pointSampleTex2D(Texture2D sam, SamplerState samp, float2 uv)//, float4 st) st is aactually screenparam because we use screenspace
           {
               //float2 snappedUV = ((float2)((int2)(uv * st.zw + float2(1, 1))) - float2(0.5, 0.5)) * st.xy;
               float2 snappedUV = ((float2)((int2)(uv * _ScreenParams.zw + float2(1, 1))) - float2(0.5, 0.5)) * _ScreenParams.xy;
               return  SAMPLE_TEXTURE2D(sam, samp, float4(snappedUV.x, snappedUV.y, 0, 0));
           }

           // License Creative Commons Attribution - NonCommercial - ShareAlike 3.0 Unported License. 
// Created by S. Guillitte 2015 



float2 cmul(float2 a , float2 b) { return float2 (a.x * b.x - a.y * b.y , a.x * b.y + a.y * b.x); }
float2 csqr(float2 a) { return float2 (a.x * a.x - a.y * a.y , 2. * a.x * a.y); }


float2x2 rot(float a) {
     return float2x2 (cos(a) , sin(a) , -sin(a) , cos(a));
 }

float2 iSphere(in float3 ro , in float3 rd , in float4 sph) // from iq 
 {
     float3 oc = ro - sph.xyz;
     float b = dot(oc , rd);
     float c = dot(oc , oc) - sph.w * sph.w;
     float h = b * b - c;
     if (h < 0.0) return float2 (-1.0, -1.0);
     h = sqrt(h);
     return float2 (-b - h , -b + h);
 }

float map(in float3 p) {

     float res = 0.;

    float3 c = p;
     for (int i = 0; i < 10; ++i) {
        p = .7 * abs(p) / dot(p , p) - .7;
        p.yz = csqr(p.yz);
        p = p.zxy;
        res += exp(-19. * abs(dot(p , c)));

      }
     return res / 2.;
 }



float3 raymarch(in float3 ro , float3 rd , float2 tminmax)
 {
    float t = tminmax.x;
    float dt = .02;
    // float dt = .2 - .195 * cos ( _Time.y * .05 ) ; // animated 
   float3 col = float3 (0. , 0. , 0.);
   float c = 0.;
   for (int i = 0; i < 64; i++)
     {
       t += dt * exp(-2. * c);
       if (t > tminmax.y) break;
       float3 pos = ro + t * rd;

       c = map(ro + t * rd);

       col = .99 * col + .08 * float3 (c * c , c , c * c * c); // greenExtended 
        // col = .99 * col + .08 * float3 ( c * c * c , c * c , c ) ; // blueExtended 
    }
   return col;
}


half4 LitPassFragment(Varyings input) : SV_Target  {
half4 fragColor = half4 (1 , 1 , 1 , 1);
float2 fragCoord = ((input.screenPos.xy) / (input.screenPos.w + FLT_MIN)) * _ScreenParams.xy;
     float time = _Time.y;
    float2 q = fragCoord.xy / _ScreenParams.xy;
    float2 p = -1.0 + 2.0 * q;
    p.x *= _ScreenParams.x / _ScreenParams.y;
    float2 m = float2 (0. , 0.);
     if (iMouse.z > 0.0) m = iMouse.xy / _ScreenParams.xy * 3.14;
    m -= .5;

    // camera 

   float3 ro = zoom * float3 (4., 4., 4.);
   ro.yz = mul(ro.yz,rot(m.y));
   ro.xz = mul(ro.xz,rot(m.x + 0.1 * time));
   float3 ta = float3 (0.0 , 0.0 , 0.0);
   float3 ww = normalize(ta - ro);
   float3 uu = normalize(cross(ww , float3 (0.0 , 1.0 , 0.0)));
   float3 vv = normalize(cross(uu , ww));
   float3 rd = normalize(p.x * uu + p.y * vv + 4.0 * ww);


   float2 tmm = iSphere(ro , rd , float4 (0. , 0. , 0. , 2.));

   // raymarch 
 float3 col = raymarch(ro , rd , tmm);
 if (tmm.x < 0.) col = SAMPLE_TEXTURECUBE_LOD(_Channel0 , sampler_Channel0 , rd, 0).rgb;
 else {
     float3 nor = (ro + tmm.x * rd) / 2.;
     nor = reflect(rd , nor);
     float fre = pow(.5 + clamp(dot(nor , rd) , 0.0 , 1.0) , 3.) * 1.3;
     col += SAMPLE_TEXTURECUBE_LOD(_Channel0 , sampler_Channel0 , nor, 0).rgb * fre;

  }

 // shade 

col = .5 * (log(1. + col));
col = clamp(col , 0. , 1.);
fragColor = float4 (col , 1.0);
fragColor.xyz -= 0.15;
return fragColor;
}


//half4 LitPassFragment(Varyings input) : SV_Target
//{
//    [FRAGMENT]
//    //float2 uv = input.uv;
//    //SAMPLE_TEXTURE2D_LOD(_BaseMap, sampler_BaseMap, uv + float2(-onePixelX, -onePixelY), _Lod);
//    //_ScreenParams.xy 
//    //half4 color = half4(1, 1, 1, 1);
//    //return color;
//}
ENDHLSL
}
        }
}