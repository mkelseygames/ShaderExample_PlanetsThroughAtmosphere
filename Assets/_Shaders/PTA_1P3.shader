// mkelsey - PTA_1P3 - UPDATE: Normal Affector Testing [P11]. 
// "Planet Through Atmosphere" surface shader, designed to 
// emulate planetary atmosphere scattering on large objects.

Shader "Custom/PTA_1P3"
{
	Properties 
	{
		_MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
		_Color ("Main Color", Color) = (1,1,1,1)
		_RimColor ("Rim Color", Color) = (1,1,1,1)
		_RimPower ("Rim Power", Range(0.1, 10.0)) = 2.0
		_RimBlend ("Rim Blend", Range(0, 1)) = 0.9
		_SkySaturation ("Sky Saturation", Range (0.1, 5)) = 3.0
		_ReflectionLOD ("Reflection LOD", Range (0, 4)) = 4.0
		_RimConcentration ("Rim Concentration", Range (-1, 1)) = 0.25
		_ShadowAlpha ("Shadow Alpha", Range(0, 1)) = 1.0
		_ShadowBlend ("Shadow Blend", Range(0.5, 6)) = 2.0

		NAffectorTest ("NAffectorTest", Range(-1.0, 1.0)) = 0.0// Test // [P11]
	}

	SubShader 
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
		//Fog { Mode Off } // [P7]

		ZWrite On
		Blend SrcAlpha OneMinusSrcAlpha
		Cull Back
		LOD 200

		CGPROGRAM
		#pragma surface surf AlphaLambert alpha:fade nofog // Remove Unity Fog + // [P7]
		#include "ColorFunctions.cginc"

		sampler2D _MainTex;
		fixed4 _Color;

		fixed4 _RimColor;
		float _RimPower;
		half _RimBlend;
		float _SkySaturation;
		float _ReflectionLOD;
		half _RimConcentration;
		half _ShadowAlpha;
		float _ShadowBlend;

		float NAffectorTest;// Test // [P11]

		struct Input 
		{
			float2 uv_MainTex;
			float3 viewDir;
			float3 worldPos;
		};

		float3 Saturator (float3 c, float saturationAmount)
		{
			float3 HSL = RGBtoHSL(c.rgb);
			// ^ Converting our color to HSL. // [P2]
			HSL.g *= saturationAmount;
			// ^ Set our desired saturation. // [P2]
			return HSLtoRGB(HSL);
			// ^ Convert back to RGB and return. // [P2]
		}

		// Custom Lighting + // [P5]
        half4 LightingAlphaLambert (SurfaceOutput s, half3 lightDir, half atten) 
        {
       		fixed NdotL = dot (s.Normal, lightDir);// Simple Lambert Model
       		// ^ Calculate the dot product of the surfaces normals and light direction. // [P5]
			fixed4 c;
			c.rgb = s.Albedo * _LightColor0.rgb * (NdotL * atten);

			// Shadow Invert Fix / Rim Dark Fade Fix + // [P10.3]
			fixed3 cS = saturate (c.rgb);// Color Saturated (Minus Invert)
			fixed3 cM = lerp(c.rgb, cS, _ShadowAlpha);// Mix Color Via Shadow Alpha - Equates to a richer color when not using Alpha
			c.rgb = cM;

			c.a = (1.0 - (s.Alpha - pow(clamp(NdotL-NdotL*NAffectorTest, 0.0, 1.0), _ShadowBlend) * atten) * _ShadowAlpha) * _Color.a; // [P9 /.2] Alpha Correction
			// ^ Alpha value is equal to 1 minus the original alpha value - saturated lighting mul the shadows alpha value, overall multiplying by the color alpha value. [P6]
			return c;
		}

		void surf (Input IN, inout SurfaceOutput o)
		{
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			o.Alpha = c.a;

			// Rim Lighting Skybox Blend + // [P3]
			float3 worldViewDir = normalize(UnityWorldSpaceViewDir(IN.worldPos));
	        // Obtain world space normal // [P3]
	        float3 worldNormal = UnityObjectToWorldNormal(o.Normal);
	        // Calculate world space reflection vector // [P3]
	        float3 worldRefl = reflect(-worldViewDir, worldNormal);
	        // Sample the default reflection cubemap, using the reflection vector // [P3]
	        half4 skyData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, worldRefl, _ReflectionLOD);
	        // Decode cubemap data into actual color // [P3]
	        half3 skyColor = DecodeHDR (skyData, unity_SpecCube0_HDR);

			// Rim Lighting + // [P1]
		 	half rim = 1.0 - saturate(dot(normalize(lerp(IN.viewDir, -_WorldSpaceLightPos0, _RimConcentration)), o.Normal)); // [P1] [P4]
		 	// ^ Obtain the dot product (-1 to 1) of the angle between our view dir, and the surfaces normal. // [P1]
		 	// ^ Normalize our view direction to ensure we are returning a value between 0 and 1. // [P1]
		 	// ^ Saturate clamps the dot product value between 0 and 1 and we do not want any thing above or below for the rim. // [P1]
		 	// ^ Lerp between our view dir and lighting position, to control the concentration of the rim lighting // [P4]
		 	o.Emission = lerp(_RimColor.rgb, 
		 					  Saturator(skyColor.rgb, 
		 					  _SkySaturation), _RimBlend) * pow(rim, _RimPower); // [P1] [P2]
		 	// ^ Here we are setting our surface emission value to our desired rim color, times by rim raised to the power of our desired rim power. // [P1]
		 	// ^ Lerping between the ambient skybox color and our desired rim color. // [P2]
		}
	ENDCG
	}
Fallback "Legacy Shaders/Transparent/VertexLit"
}