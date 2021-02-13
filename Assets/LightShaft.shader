Shader "Unlit/LightShaft"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _BaseMap("Base Map", 2D) = "white" {}
        _MaxStep("Max Step", Range(2, 32)) = 4
        _StepSize("Step Size", Float) = 1

    }
        SubShader
    {
        Tags { "RenderType" = "Transparent" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" "Queue" = "Transparent"}
        LOD 100

        Pass
        {
            Name "RayMarching"

            Blend One One
            ZWrite Off
            Cull Back
            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #define MAIN_LIGHT_CALCULATE_SHADOWS

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            float4 _BaseMap_ST;
            half4 _BaseColor;
            half _StepSize;
            half _MaxStep;

            struct Attributes
            {
                float4 positionOS       : POSITION;
            };

            struct Varyings
            {
                float3 worldPos        : TEXCOORD0;
                float4 screenPos       : TEXCOORD1;
                float4 vertex : SV_POSITION;
            };
            half3 RayMarching(float3 start, float3 end, int step, half stepsize) {
                half maxLen = length(end - start);
                float3 marchingDir = normalize(end - start);
                half marchingLen = 0;
                half3 lightColor = 0;
                [loop]
                for (int i = 0; i < step; ++i) {
                    marchingLen += i * stepsize;
                    if (marchingLen <= maxLen)
                    {
                        float3 samplePos = start + marchingLen * marchingDir;
                        float4 localPos = mul(unity_WorldToObject, float4(samplePos, 1));
                        half4 c_xy = SAMPLE_TEXTURE2D_X(_BaseMap, sampler_BaseMap, localPos.xy + 0.5);
                        half4 c_zy = SAMPLE_TEXTURE2D_X(_BaseMap, sampler_BaseMap, localPos.zy + 0.5);
                        float4 shadowCoord = TransformWorldToShadowCoord(samplePos);
                        half shadow = MainLightRealtimeShadow(shadowCoord);
                        lightColor += c_xy.rgb * c_zy.rgb * shadow;
                    }
                }
                return lightColor;
            }

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.vertex = vertexInput.positionCS;
                output.worldPos = vertexInput.positionWS;
                output.screenPos = vertexInput.positionNDC;
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                float2 uv = input.screenPos.xy / input.screenPos.w; 
                float rawDepth = SampleSceneDepth(uv);
                float sceneZ =  LinearEyeDepth(rawDepth, _ZBufferParams);
                half3 viewDirWS = normalize(input.worldPos - GetCameraPositionWS());
                float3 end = GetCameraPositionWS() + sceneZ * viewDirWS;
                float3 start = input.worldPos;
                half3 lightColor = RayMarching(start, end, (int)_MaxStep, _StepSize);
                return half4(lightColor * _BaseColor.rgb, 1);
            }
            ENDHLSL
        }
    }
}
