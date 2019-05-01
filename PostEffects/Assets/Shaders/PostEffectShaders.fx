///////////////////////////////////////////////////////////////////////////////
// PostEffect Shader
///////////////////////////////////////////////////////////////////////////////

cbuffer PerFrameCB : register(b0)
{
	matrix matProjection;
	matrix matView;
	float  time;
	float3 colour1;
	float3 colour2;
	float matSize;
	float matSizeSq;
	float padding[3];
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
	//c += 0.15f;

	//c = (col.x + col.y + col.z) / 3;

	return float4(c, c, c, 1);
}

///////////////////////////////////////////////////////////////////////////////
// BAYER DITHERING
///////////////////////////////////////////////////////////////////////////////

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

static int bayerMatrix2x2[2][2] = { 
	{0, 2},
	{3, 1} };

static int dotMatrix2x2[2][2] = {
	{3, 1},
	{0, 2} };

static int bayerMatrix3x3[3][3] = {
	{0, 7, 3},
	{6, 5, 2},
	{4, 1, 8} };

static int bayerMatrix4x4[4][4] = { 
	{ 0,		8,		2,		10 },
	{ 12,		4,		14,		6 },
	{ 3,		11,		1,		9 },
	{15,		7,		13,		5 } };

static int bayerMatrix4x4v2[4][4] = {
	{ 15,		3,		12,		0 },
	{ 7,		11,		4,		8 },
	{ 13,		1,		14,		2 },
	{ 5,		9,		6,		10 } };


static int dotMatrix4x4[4][4] = {
	{ 12,		5,		6,		13 },
	{ 4,		0,		1,		7 },
	{ 11,		3,		2,		8 },
	{15,		10,		9,		14 } };

static int bayerMatrix8x8[8][8] = {
{ 0, 32, 8, 40, 2, 34, 10, 42}, /* 8x8 Bayer ordered dithering */
{48, 16, 56, 24, 50, 18, 58, 26}, /* pattern. Each input pixel */
{12, 44, 4, 36, 14, 46, 6, 38}, /* is scaled to the 0..63 range */
{60, 28, 52, 20, 62, 30, 54, 22}, /* before looking in this table */
{ 3, 35, 11, 43, 1, 33, 9, 41}, /* to determine the action. */
{51, 19, 59, 27, 49, 17, 57, 25},
{15, 47, 7, 39, 13, 45, 5, 37},
{63, 31, 55, 23, 61, 29, 53, 21} };

static int dotMatrix8x8[8][8] = {
{24,	10,		12,		26,		35,		47,		49,		37},
{ 8,	0,		2,		14,		45,		59,		61,		51},
{ 22,	6,		4,		16,		43,		57,		63,		53},
{ 30,	20,		18,		28,		33,		41,		55,		39},
{ 34,	46,		48,		36,		25,		11,		13,		27},
{ 44,	58,		60,		50,		9,		1,		3,		15},
{ 42,	56,		62,		52,		23,		7,		5,		17},
{ 32,	40,		54,		38,		31,		21,		19,		29}
};

float rand_1_05(float2 uv)
{
	float2 noise = (frac(sin(dot(uv, float2(12.9898, 78.233)*2.0)) * 43758.5453));
	return abs(noise.x + noise.y) * 0.5;
}

float find_closest_bayer(int x, int y, float c0, int i)
{
	float limit = 0;

	limit = (matSize == 2) ? (x < matSize) ? (bayerMatrix2x2[x][y] + 1) / matSizeSq : 0.0f : limit;
	limit = (matSize == 4) ? (x < matSize) ? (bayerMatrix4x4[x][y] + 1) / matSizeSq : 0.0f : limit;
	limit = (matSize == 8) ? (x < matSize) ? (bayerMatrix8x8[x][y] + 1) / matSizeSq : 0.0f : limit;

	return(c0 < limit) ? colour1[i] : colour2[i];
}

float find_closest_bayerR1(int x, int y, float c0, int i)
{
	float limit = 0;

	limit = (matSize == 4) ? (x < matSize) ? (bayerMatrix4x4v2[x][y] + 1) / matSizeSq : 0.0f : limit;

	return(c0 < limit) ? colour1[i] : colour2[i];
}

float find_closest_dot(int x, int y, float c0, int i)
{
	float limit = 0;

	limit = (matSize == 2) ? (x < matSize) ? (dotMatrix2x2[x][y] + 1) / matSizeSq : 0.0f : limit;
	limit = (matSize == 4) ? (x < matSize) ? (dotMatrix4x4[x][y] + 1) / matSizeSq : 0.0f : limit;
	limit = (matSize == 8) ? (x < matSize) ? (dotMatrix8x8[x][y] + 1) / matSizeSq : 0.0f : limit;

	return(c0 < limit) ? colour1[i] : colour2[i];
}

float4 PS_PostEffect_Bayer_Dither(VertexOutput input) : SV_TARGET
{
	// Courtesy of: http://devlog-martinsh.blogspot.com/2011/03/glsl-8x8-bayer-matrix-dithering.html
	float4 col = gColourSurface.Sample(linearMipSampler, input.uv);
	float4 grayscale = Grayscale(col);
	float2 xy = input.vpos.xy;
	int x = (int)(xy.x % matSize);
	int y = (int)(xy.y % matSize);

	float3 finalRGB;

	finalRGB.x = find_closest_bayer(x, y, grayscale.x, 0);
	finalRGB.y = find_closest_bayer(x, y, grayscale.y, 1);
	finalRGB.z = find_closest_bayer(x, y, grayscale.z, 2);

	float finalC = (finalRGB.x > 0.5) ? colour1 : colour2;

	return float4(finalRGB.xyz, 1.0);
}

float4 PS_PostEffect_Bayer_Dot_Dither(VertexOutput input) : SV_TARGET
{
	// Courtesy of: http://devlog-martinsh.blogspot.com/2011/03/glsl-8x8-bayer-matrix-dithering.html
	float4 col = gColourSurface.Sample(linearMipSampler, input.uv);
	float4 grayscale = Grayscale(col);
	float2 xy = input.vpos.xy;
	int x = (int)(xy.x % matSize);
	int y = (int)(xy.y % matSize);

	float3 finalRGB;

	finalRGB.x = find_closest_dot(x, y, grayscale.x, 0);
	finalRGB.y = find_closest_dot(x, y, grayscale.y, 1);
	finalRGB.z = find_closest_dot(x, y, grayscale.z, 2);

	float finalC = (finalRGB.x > 0.5) ? colour1 : colour2;

	return float4(finalRGB.xyz, 1.0);
}

float4 PS_PostEffect_Bayer_Random_Dither(VertexOutput input) : SV_TARGET
{
	// Courtesy of: http://devlog-martinsh.blogspot.com/2011/03/glsl-8x8-bayer-matrix-dithering.html
	float4 col = gColourSurface.Sample(linearMipSampler, input.uv);
	float4 grayscale = Grayscale(col);
	float2 xy = input.vpos.xy;
	int x = (int)(xy.x % matSize);
	int y = (int)(xy.y % matSize);

	float3 finalRGB;

	float rand = rand_1_05(input.vpos.xy);

	finalRGB.x = (rand > 0.5f) ? find_closest_bayer(x, y, grayscale.x, 0) : find_closest_bayer(y, x, grayscale.x, 0);
	finalRGB.y = (rand > 0.5f) ? find_closest_bayer(x, y, grayscale.y, 1) : find_closest_bayer(y, x, grayscale.y, 1);
	finalRGB.z = (rand > 0.5f) ? find_closest_bayer(x, y, grayscale.z, 2) : find_closest_bayer(y, x, grayscale.z, 2);

	float finalC = (finalRGB.x > 0.5) ? colour1 : colour2;

	return float4(finalRGB.xyz, 1.0);
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


