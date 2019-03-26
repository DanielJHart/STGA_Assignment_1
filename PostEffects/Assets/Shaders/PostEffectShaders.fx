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
	float size = 8.0f;
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

///////////////////////////////////////////////////////////////////////////////
// No Post Effect
float4 PS_PostEffect_None(VertexOutput input) : SV_TARGET
{
 	return gColourSurface.Sample(linearMipSampler, input.uv);
}

float4 Grayscale(float4 col)
{
	float c = col.x * 0.299 + col.y * 0.587 + col.z * 0.114;
	c += 0.15f;
	return float4(c, c, c, 1);
}

///////////////////////////////////////////////////////////////////////////////
// BAYER DITHERING
///////////////////////////////////////////////////////////////////////////////

int MatSize = 4;
int indexMatrix4x4[16] = {  0,		8,		2,		10,
							12,		4,		14,		6,
							3,		11,		1,		9,
							15,		7,		13,		5 };

float indexValue(int x, int y)
{
	int indX = x % MatSize;
	int indY = y % MatSize;
	return indexMatrix4x4[(indX + indY * MatSize)] / 16.0f;
}


float4 PS_PostEffect_Bayer_Dither(VertexOutput input) : SV_TARGET
{
	float c = PS_PostEffect_CrossStitch(input); //gColourSurface.Sample(linearMipSampler, input.uv); //= Grayscale(gColourSurface.Sample(linearMipSampler, input.uv));
	float closestColour = (c.x < 0.5f) ? 0 : 1;
	float secondClosestColour = 1 - closestColour;
	float d = indexValue(input.uv.x * 1024, input.uv.y * 768);
	float distance = abs(closestColour - c.x);
	float retc = (distance < 0) ? closestColour : secondClosestColour;
	return float4(retc, retc, retc, 1);
}

///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
// FLOYD-STEINBERG DITHERING
///////////////////////////////////////////////////////////////////////////////



float4 FindClosestPaletteColour(float4 col)
{	
	int r = round(col.x);
	int g = round(col.y);
	int b = round(col.z);

	return float4(r, g, b, 1);

}															  
float4 GetError(int diffX, int diffY, float2 uv)
{
	float u = uv.x + (diffX * (1 / 1024));
	float v = uv.y + (diffY * (1 / 768));
	float4 c = gColourSurface.Sample(linearMipSampler, float2(u, v));
	c = Grayscale(c);
	float4 p = FindClosestPaletteColour(c);
	return float4((p - c).xyz, 1);
}

float4 PS_PostEffect_Floyd_Steinberg_Dither(VertexOutput input) : SV_TARGET
{
	float4 c = gColourSurface.Sample(linearMipSampler, input.uv);
	c = Grayscale(c);
	float4 palette = FindClosestPaletteColour(c);

	palette += GetError(-1, 0, input.uv) * (7.0 / 16.0);
	palette += GetError(1, -1, input.uv) * (3.0 / 16.0);
	palette += GetError(0, -1, input.uv) * (5.0 / 16.0);
	palette += GetError(-1, -1, input.uv) * (1.0 / 16.0);

	return palette;
}


