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

int MatSize = 8;
float matSizeSq = 64.f;


int indexMatrix8x8[8][8] = {{ 0, 32, 8, 40, 2, 34, 10, 42 },
							{48, 16, 56, 24, 50, 18, 58, 26},
							{12, 44, 4, 36, 14, 46, 6, 38},
							{60, 28, 52, 20, 62, 30, 54, 22},
							{3, 35, 11, 43, 1, 33, 9, 41},
							{51, 19, 59, 27, 49, 17, 57, 25},
							{15, 47, 7, 39, 13, 45, 5, 37},
							{63, 31, 55, 23, 61, 29, 53, 21 }};

////float indexValue(int x, int y)
////{
////	int indX = x % MatSize;
////	int indY = y % MatSize;
////	return indexMatrix8x8[((indX + indY) * MatSize)] / matSizeSq;
////}

////float Dither(float color, int x , int y) 
////{
////	float closestColor = (color < 0.5) ? 0 : 1;
////	float secondClosestColor = 1 - closestColor;
////	float d = indexValue(x, y);
////	float distance = abs(closestColor - color);
////	return (distance < d) ? secondClosestColor : closestColor;
////}
static int indexMatrix4x4[4][4] = { { 0,		8,		2,		10 },
							{ 12,		4,		14,		6 },
							{ 3,		11,		1,		9 },
							{15,		7,		13,		5 } };

static int dither[8][8] = {
{ 0, 32, 8, 40, 2, 34, 10, 42}, /* 8x8 Bayer ordered dithering */
{48, 16, 56, 24, 50, 18, 58, 26}, /* pattern. Each input pixel */
{12, 44, 4, 36, 14, 46, 6, 38}, /* is scaled to the 0..63 range */
{60, 28, 52, 20, 62, 30, 54, 22}, /* before looking in this table */
{ 3, 35, 11, 43, 1, 33, 9, 41}, /* to determine the action. */
{51, 19, 59, 27, 49, 17, 57, 25},
{15, 47, 7, 39, 13, 45, 5, 37},
{63, 31, 55, 23, 61, 29, 53, 21} };

//#define VERSION_1
float4 color1 = float4(0.f, 0.f, 0.f, 1.f);
float4 color2 = float4(1.f, 1.f, 1.f, 1.f);

float find_closest(int x, int y, float c0)
{
	float limit = (x < 8) ? (dither[x][y] + 1) / 64.0f : 0.0f;

	return(c0 < limit) ? 0.0 : 1.0;
}



float4 PS_PostEffect_Bayer_Dither(VertexOutput input) : SV_TARGET
{
#ifdef VERSION_1
	float c = gColourSurface.Sample(linearMipSampler, input.uv); //= Grayscale(gColourSurface.Sample(linearMipSampler, input.uv));
	float retc = Dither(c.x, input.vpos.x, input.vpos.y);
	return float4(retc, retc, retc, 1);
#else
	// Courtesy of: http://devlog-martinsh.blogspot.com/2011/03/glsl-8x8-bayer-matrix-dithering.html
	//float4 pixellatedCol = PS_PostEffect_Pixelate(input);
	float4 col = gColourSurface.Sample(linearMipSampler, input.uv);
	float4 grayscale = Grayscale(col);
	float2 xy = input.vpos.xy;
	int x = (int)(xy.x % 8);
	int y = (int)(xy.y % 8);

	float3 finalRGB;

	finalRGB.x = find_closest(x, y, grayscale.x);
	finalRGB.y = find_closest(x, y, grayscale.y);
	finalRGB.z = find_closest(x, y, grayscale.z);

	float finalC = (finalRGB.x > 0.5) ? color1 : color2;

	return float4(finalRGB.xyz, 1.0);

#endif
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


