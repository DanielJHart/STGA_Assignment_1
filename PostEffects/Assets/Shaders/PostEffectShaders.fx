///////////////////////////////////////////////////////////////////////////////
// PostEffect Shader
///////////////////////////////////////////////////////////////////////////////

cbuffer PerFrameCB : register(b0)
{
	matrix matProjection;
	matrix matView;
	float  time;
	float  padding[3];
};

cbuffer PerDrawCB : register(b1)
{
    matrix matMVP;
};

SamplerState linearMipSampler : register(s0);

struct VertexInput
{
    float3 pos   : POSITION;
    float4 color : COLOUR;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 uv : TEXCOORD;
};

struct VertexOutput
{
    float4 vpos  : SV_POSITION;
    float2 uv : TEXCOORD;
};



// PostEffect surfaces.
Texture2D gColourSurface : register(t0);
Texture2D gDepthSurface : register(t1);

///////////////////////////////////////////////////////////////////////////////
// Passthrough quad info in the vertex shader.
VertexOutput VS_PostEffect(VertexInput input)
{
	VertexOutput output;
	output.vpos = float4(input.pos.xyz, 1.0f);
	output.uv = input.uv.xy;

    return output;
}

///////////////////////////////////////////////////////////////////////////////
// No Post Effect
float4 PS_PostEffect_None(VertexOutput input) : SV_TARGET
{
 	return gColourSurface.Sample(linearMipSampler, input.uv);
}


///////////////////////////////////////////////////////////////////////////////
