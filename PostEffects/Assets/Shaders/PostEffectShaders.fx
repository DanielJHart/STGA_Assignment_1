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

// Pixelate Effect
float4 PS_PostEffect_Pixelate(VertexOutput input) : SV_TARGET
{
	float scale = 150.0;
	float2 UV = floor(input.uv * scale) / scale;
	return gColourSurface.Sample(linearMipSampler, UV);
}

// Cross Stitch Effect. Gathered from: https://www.geeks3d.com/20110408/cross-stitching-post-processing-shader-glsl-filter-geexlab-pixel-bender/
float4 PS_PostEffect_CrossStitch(VertexOutput input) : SV_TARGET
{
	float4 c = float4(0, 0, 0, 0);
	float size = 4.0f;
	float2 cPos = input.uv * float2(1024, 768);
	float2 tlPos = floor(cPos / float2(size, size));
	tlPos *= size;
	int remX = int(cPos.x % size);
	int remY = int(cPos.y % size);

	if (remX == 0 && remY == 0)
	{
		tlPos = cPos;
	}

	float2 blPos = tlPos;
	blPos.y += (size - 1.0);
	if (remX == remY || (((int(cPos.x) - int(blPos.x) == (int(blPos.y) - int(cPos.y))))))
	{
		c = gColourSurface.Sample(linearMipSampler, tlPos * float2(1.0 / 1024, 1.0 / 768)) * 1.4;
	}
	else
	{
		c = float4(0, 0, 0, 1);
	}

	return c;
}
///////////////////////////////////////////////////////////////////////////////
