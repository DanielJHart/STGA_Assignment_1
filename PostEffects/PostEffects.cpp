#include "Framework.h"

#include "ShaderSet.h"
#include "Mesh.h"
#include "Texture.h"
#include <string>
#include <random>
#define MAX_PALETTES 4
#define kNumberOfAlgorithms 4

//================================================================================
// Minimal Application
// An example of how to use selected parts of this framework.
//================================================================================
class MinimalApp : public FrameworkApp
{
public:

	struct PerFrameCBData
	{
		m4x4 m_matProjection;
		m4x4 m_matView;
		f32	m_time;
		f32 colour1[3];
		f32	colour2[3];
		f32 matSize;
		f32 matSizeSq;
		f32 padding[3];
	};

	struct PerDrawCBData
	{
		m4x4 m_matMVP;
	};

	struct ColourPreset
	{
		ColourPreset() {};
		ColourPreset(f32 r1, f32 g1, f32 b1, f32 r2, f32 g2, f32 b2, std::string n)
		{

			Colour1[0] = r1;
			Colour1[1] = g1;
			Colour1[2] = b1;

			Colour2[0] = r2;
			Colour2[1] = g2;
			Colour2[2] = b2;

			name = n;
		}

		f32 Colour1[3];
		f32 Colour2[3];
		std::string name;
	};

	void SetupModelsAndTextures(SystemsInterface& systems)
	{
		// Initialize a mesh directly.
		create_mesh_cube(systems.pD3DDevice, m_meshArray[0], 0.5f);

		////create_mesh_from_obj(systems.pD3DDevice, m_meshArray[1], "Assets/Models/Table2obj.obj", 0.01f);

		// Initialize a mesh from an .OBJ file
		create_mesh_from_obj(systems.pD3DDevice, m_meshArray[1], "Assets/Models/apple.obj", 0.01f);
		create_mesh_quad_xy(systems.pD3DDevice, m_meshArray[2], systems.height / 2);
		create_mesh_quad_xy(systems.pD3DDevice, m_meshArray[3], systems.height / 2);

		// Initialise some textures;
		m_textures[0].init_from_dds(systems.pD3DDevice, "Assets/Textures/gradient.dds");
		m_textures[1].init_from_dds(systems.pD3DDevice, "Assets/Textures/apple_diffuse.dds");
		m_textures[2].init_from_dds(systems.pD3DDevice, "Assets/Textures/lenna.dds");
		m_textures[3].init_from_dds(systems.pD3DDevice, "Assets/Textures/gradient.dds");
	}

	void SetupPalettes()
	{
		palettes[0] = ColourPreset( 0.f, 0.f, 0.f, 1.f, 1.f, 1.f, "Black And White" ); // #000000, #FFFFFF
		palettes[1] = ColourPreset(0.203, 0.203, 0.105, 0.898, 1, 0.992, "Obra Dinn 1"); // #33321A, #CCFFFF
		palettes[2] = ColourPreset(0.239, 0.152, 0.109, 0.984, 0.776, 0.360, "Obra Dinn 2"); // #3B251A, #FBC757
		palettes[3] = ColourPreset(0.f, 0.f, 0.f, 0.470, 0.780, 0.188, "Classic Computer Graphics"); // #3B251A, #FBC757

		for (int i = 0; i < 3; ++i)
		{
			m_perFrameCBData.colour1[i] = palettes[0].Colour1[i];
			m_perFrameCBData.colour2[i] = palettes[0].Colour2[i];
		}
	}

	void SetupPostProcessNames()
	{
		m_PostEffectNames[0] = "Bayer_Dither";
		m_PostEffectNames[1] = "Bayer_Random_Dither";
		m_PostEffectNames[2] = "Bayer_Dot_Dither";
		m_PostEffectNames[kNumberOfAlgorithms - 1] = "None";
	}

	void HandleImGui(SystemsInterface& systems)
	{
		ImGui::Text("------ Orthographic Controls ------");
		ImGui::Checkbox("Orthographic", &m_Ortho);
		if (m_Ortho)
		{
			if (!systems.pCamera->isOrtho)
			{
				// Set up camera for orthographic view
				m_position = v3(0.0f, 0.0f, -1.0f);
				m_size = 1.0f;
				systems.pCamera->eye = v3(0.f, 0.f, -1.f);
				systems.pCamera->look_at(v3(0.f, 0.f, 0.f));
				systems.pCamera->up = (v3(0.f, 1.f, 0.f));
				systems.pCamera->set_ortho(true);
			}

			if (ImGui::Button("Switch Image"))
			{
				if (m_imageToUse == 2) { m_imageToUse = 3; }
				else { m_imageToUse = 2; }
			}
		}
		else if (systems.pCamera->isOrtho)
		{
			// Set up camera for perspective view
			systems.pCamera->eye = v3(12.f, 7.7f, 11.8f);
			systems.pCamera->look_at(v3(0.f, 0.f, 0.f));
			systems.pCamera->up = (v3(0.f, 1.f, 0.f));
			systems.pCamera->set_ortho(false);
		}

		ImGui::Text("--------------------------------");
		ImGui::Text("\n------ Algorithm Controls ------");
		ImGui::Text("Dither Algorithm");
		
		if (ImGui::ListBox("", &m_postEffect, &m_PostEffectNames[0], kNumberOfAlgorithms))
		{
			std::string algorithmToUse = "PS_PostEffect_";
			algorithmToUse += m_PostEffectNames[m_postEffect];

			m_postEffectShader.init(systems.pD3DDevice
				, ShaderSetDesc::Create_VS_PS("Assets/Shaders/PostEffectShaders.fx", "VS_PostEffect", algorithmToUse.c_str())
				, { VertexFormatTraits<MeshVertex>::desc, VertexFormatTraits<MeshVertex>::size }
			);
		}

		if (m_postEffect < kNumberOfAlgorithms - 1)
		{
			if (ImGui::Button("Change Matrix Size"))
			{
				m_matSize *= 2;
				if (m_matSize == 16)
				{
					m_matSize = 2;

				}
				m_matSizeSq = m_matSize * m_matSize;
			}

			ImGui::Text(("Matrix Size: " + std::to_string(m_matSize) + "x" + std::to_string(m_matSize)).c_str());
		}

		ImGui::Text("--------------------------------");
		ImGui::Text("\n------ Colour Controls ------");

		static float col1[3], col2[3];
		if (ImGui::ColorEdit3("Colour 1", m_perFrameCBData.colour1) ||
			ImGui::ColorEdit3("Colour 2", m_perFrameCBData.colour2))
		{
			m_colourName = "Custom";
		}

		if (ImGui::Button("Next preset"))
		{
			++m_colourPresetSelected;
			if (m_colourPresetSelected == MAX_PALETTES)
			{
				m_colourPresetSelected = 0;
			}
			for (int i = 0; i < 3; ++i)
			{
				m_perFrameCBData.colour1[i] = palettes[m_colourPresetSelected].Colour1[i];
				m_perFrameCBData.colour2[i] = palettes[m_colourPresetSelected].Colour2[i];
				m_colourName = palettes[m_colourPresetSelected].name;
			}
		}

		ImGui::Text(("Colour Set: " + m_colourName).c_str());
		ImGui::Text("--------------------------------");
	}

	void on_init(SystemsInterface& systems) override
	{
		// Define random generator with Gaussian distribution
		const double mean = 0.0;
		const double stddev = 0.08;
		std::default_random_engine generator;
		std::normal_distribution<double> dist(mean, stddev);

		for (int i = 0; i < 10; ++i)
		{
			float x = dist(generator);


			x = 1;
		}

		SetupPostProcessNames();
		SetupPalettes();

		// Create our rendering and depth surfaces.
		create_render_surfaces(systems.pD3DDevice, systems.pD3DContext, systems.width, systems.height);

		// create fullscreen quad for post-fx / lighting passes. (-1, 1) in XY
		create_mesh_quad_xy(systems.pD3DDevice, m_fullScreenQuad, 1.0f);

		// Setup the camera.
		m_position = v3(0.0f, 0.0f, -1.0f);
		m_size = 1.0f;
		systems.pCamera->eye = v3(0.f, 0.f, -1.f);
		systems.pCamera->look_at(v3(0.f, 0.f, 0.f));
		systems.pCamera->up = (v3(0.f, 1.f, 0.f));

		// Compile a set of shaders for mesh rendering in main pass.
		m_meshShader.init(systems.pD3DDevice
			, ShaderSetDesc::Create_VS_PS("Assets/Shaders/MinimalShaders.fx", "VS_Mesh", "PS_Mesh")
			, { VertexFormatTraits<MeshVertex>::desc, VertexFormatTraits<MeshVertex>::size }
		);

		std::string algorithmToUse = "PS_PostEffect_";
		algorithmToUse += m_PostEffectNames[m_postEffect];

		// Compile a set of shaders for our post effect
		m_postEffectShader.init(systems.pD3DDevice
			, ShaderSetDesc::Create_VS_PS("Assets/Shaders/PostEffectShaders.fx", "VS_PostEffect", algorithmToUse.c_str())
			, { VertexFormatTraits<MeshVertex>::desc, VertexFormatTraits<MeshVertex>::size }
		);

		constexpr int size = sizeof(PerFrameCBData);

		// Create Per Frame Constant Buffer.
		m_pPerFrameCB = create_constant_buffer<PerFrameCBData>(systems.pD3DDevice);

		// Create Per Frame Constant Buffer.
		m_pPerDrawCB = create_constant_buffer<PerDrawCBData>(systems.pD3DDevice);

		SetupModelsAndTextures(systems);

		// We need a sampler state to define wrapping and mipmap parameters.
		m_pLinearMipSamplerState = create_basic_sampler(systems.pD3DDevice, D3D11_TEXTURE_ADDRESS_WRAP);

		// Setup per-frame data
		m_perFrameCBData.m_time = 0.0f;
	}

	void on_update(SystemsInterface& systems) override
	{
		//////////////////////////////////////////////////////////////////////////
		// You can use features from the ImGui library.
		// Investigate the ImGui::ShowDemoWindow() function for ideas.
		// see also : https://github.com/ocornut/imgui
		//////////////////////////////////////////////////////////////////////////

		

		// This function displays some useful debugging values, camera positions etc.
		DemoFeatures::editorHud(systems.pDebugDrawContext);

		// Update Per Frame Data.
		m_perFrameCBData.m_matProjection = systems.pCamera->projMatrix.Transpose();
		m_perFrameCBData.m_matView = systems.pCamera->viewMatrix.Transpose();
		m_perFrameCBData.m_time += 0.001f;
		m_perFrameCBData.matSize = m_matSize;
		m_perFrameCBData.matSizeSq = m_matSizeSq;
	}

	void on_render(SystemsInterface& systems) override
	{
		// Grid from -50 to +50 in both X & Z

		
		//=======================================================================================
		// The Main rendering Pass
		// Draw our scene into the off-screen render surface
		//=======================================================================================
		HandleImGui(systems);

		// Bind the render target views for colour and depth to the output merger.
		systems.pD3DContext->OMSetRenderTargets(1, &m_pColourSurfaceTargetView, m_pDepthSurfaceTargetView);

		// Clear colour and depth
		f32 clearValue[] = { 0.0f, 0.0f, 0.0f, 0.f };
		systems.pD3DContext->ClearRenderTargetView(m_pColourSurfaceTargetView, clearValue);
		systems.pD3DContext->ClearDepthStencilView(m_pDepthSurfaceTargetView, D3D11_CLEAR_DEPTH | D3D11_CLEAR_STENCIL, 1.f, 0);


		// Push Per Frame Data to GPU
		D3D11_MAPPED_SUBRESOURCE subresource;
		if (!FAILED(systems.pD3DContext->Map(m_pPerFrameCB, 0, D3D11_MAP_WRITE_DISCARD, 0, &subresource)))
		{
			memcpy(subresource.pData, &m_perFrameCBData, sizeof(PerFrameCBData));
			systems.pD3DContext->Unmap(m_pPerFrameCB, 0);
		}

		// Bind our set of shaders.
		m_meshShader.bind(systems.pD3DContext);

		// Bind Constant Buffers, to both PS and VS stages
		ID3D11Buffer* buffers[] = { m_pPerFrameCB, m_pPerDrawCB };
		systems.pD3DContext->VSSetConstantBuffers(0, 2, buffers);
		systems.pD3DContext->PSSetConstantBuffers(0, 2, buffers);

		// Bind a sampler state
		ID3D11SamplerState* samplers[] = { m_pLinearMipSamplerState };
		systems.pD3DContext->PSSetSamplers(0, 1, samplers);

		constexpr f32 kGridSpacing = 1.5f;
		constexpr u32 kNumInstances = 5;
		constexpr u32 kNumModelTypes = 4;

		if (m_Ortho)
		{
			// Bind a mesh and texture.
			m_meshArray[2].bind(systems.pD3DContext);
			m_textures[m_imageToUse].bind(systems.pD3DContext, ShaderStage::kPixel, 0);

			m4x4 matModel = m4x4::CreateTranslation(v3(0, 0, 0));
			m4x4 matMVP = matModel * systems.pCamera->vpMatrix;
			m_perDrawCBData.m_matMVP = matMVP.Transpose();
			push_constant_buffer(systems.pD3DContext, m_pPerDrawCB, m_perDrawCBData);
			m_meshArray[2].draw(systems.pD3DContext);

			// Update Per Draw Data
			m_perDrawCBData.m_matMVP = matMVP.Transpose();
			// Push to GPU
			push_constant_buffer(systems.pD3DContext, m_pPerDrawCB, m_perDrawCBData);
			// Draw the mesh.
			m_meshArray[2].draw(systems.pD3DContext);
		}
		else // Perspective
		{
			for (u32 t = 0; t < kNumModelTypes - 2; ++t)
			{
				// Bind a mesh and texture.
				m_meshArray[t].bind(systems.pD3DContext);
				m_textures[t].bind(systems.pD3DContext, ShaderStage::kPixel, 0);


				// Draw several instances
				for (u32 i = 0; i < kNumInstances; ++i)
				{
					for (u32 j = 0; j < kNumInstances; ++j)
					{
						// Compute MVP matrix.
						m4x4 matModel = m4x4::CreateTranslation(v3(i * kGridSpacing, t * kGridSpacing, j * kGridSpacing));
						m4x4 matMVP = matModel * systems.pCamera->vpMatrix;

						// Update Per Draw Data
						m_perDrawCBData.m_matMVP = matMVP.Transpose();

						// Push to GPU
						push_constant_buffer(systems.pD3DContext, m_pPerDrawCB, m_perDrawCBData);

						// Draw the mesh.
						m_meshArray[t].draw(systems.pD3DContext);
					}
				}
			}
		}
		//=======================================================================================
		// The Post FX pass
		// Draw our scene into the off-screen render surface
		//=======================================================================================

		// Bind the swap chain (back buffer) to the render target
		// Make sure to unbind the depth buffer, so we can read from it.
		systems.pD3DContext->OMSetRenderTargets(1, &systems.pSwapRenderTarget, NULL);

		

		// Bind our Colour and Depth surfaces as inputs to the pixel shader
		ID3D11ShaderResourceView* srvs[2]{ m_pColourSurfaceSRV, m_pDepthSurfaceSRV };
		systems.pD3DContext->PSSetShaderResources(0, 2, srvs);

		// Bind the PostEffect shaders
		m_postEffectShader.bind(systems.pD3DContext);

		// Draw a full screen quad.
		// This is the post effect
		m_fullScreenQuad.bind(systems.pD3DContext);
		m_fullScreenQuad.draw(systems.pD3DContext);

		// Unbind all the SRVs because we need them as targets next frame
		ID3D11ShaderResourceView* srvClear[] = { NULL, NULL };
		systems.pD3DContext->PSSetShaderResources(0, 2, srvClear);

		// re-bind depth for debugging output which is rendered after this lot.
		systems.pD3DContext->OMSetRenderTargets(1, &systems.pSwapRenderTarget, m_pDepthSurfaceTargetView);
	}

	void on_resize(SystemsInterface& systems) override
	{
		create_render_surfaces(systems.pD3DDevice, systems.pD3DContext, systems.width, systems.height);
	}

	void create_render_surfaces(ID3D11Device* pD3DDevice, ID3D11DeviceContext* pD3DContext, u32 width, u32 height)
	{
		HRESULT hr;

		// Release all outstanding references to the swap chain's buffers.
		pD3DContext->OMSetRenderTargets(0, 0, 0);

		// Destroy old colour surfaces.
		SAFE_RELEASE(m_pColourSurfaceTargetView);
		SAFE_RELEASE(m_pColourSurfaceSRV);
		SAFE_RELEASE(m_pColourSurface);

		// Destroy old depth surfaces.
		SAFE_RELEASE(m_pDepthSurfaceTargetView);
		SAFE_RELEASE(m_pDepthSurfaceSRV);
		SAFE_RELEASE(m_pDepthSurface);

		// Create a colour surface
		D3D11_TEXTURE2D_DESC desc;
		desc.Width = width;
		desc.Height = height;
		desc.MipLevels = 1;
		desc.ArraySize = 1;
		desc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
		desc.SampleDesc.Count = 1;
		desc.SampleDesc.Quality = 0;
		desc.Usage = D3D11_USAGE_DEFAULT;
		desc.BindFlags = D3D11_BIND_RENDER_TARGET | D3D11_BIND_SHADER_RESOURCE;
		desc.CPUAccessFlags = 0;
		desc.MiscFlags = 0;

		hr = pD3DDevice->CreateTexture2D(&desc, NULL, &m_pColourSurface);
		if (FAILED(hr))
		{
			panicF("Failed to create colour surface texture");
		}

		// render target views.
		hr = pD3DDevice->CreateRenderTargetView(m_pColourSurface, NULL, &m_pColourSurfaceTargetView);
		if (FAILED(hr))
		{
			panicF("Failed to create colour surface texture");
		}

		D3D11_SHADER_RESOURCE_VIEW_DESC srvDesc = {};
		srvDesc.Format = desc.Format;
		srvDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
		srvDesc.Texture2D.MostDetailedMip = 0;
		srvDesc.Texture2D.MipLevels = 1;

		hr = pD3DDevice->CreateShaderResourceView(m_pColourSurface, &srvDesc, &m_pColourSurfaceSRV);
		if (FAILED(hr))
		{
			panicF("Failed to create colour surface SRV");
		}

		// Create a depth buffer
		{
			D3D11_TEXTURE2D_DESC desc;
			desc.Width = width;
			desc.Height = height;
			desc.MipLevels = 1;
			desc.ArraySize = 1;
			desc.Format = DXGI_FORMAT_R24G8_TYPELESS; // Typeless because we are binding as SRV and DepthStencilView
			desc.SampleDesc.Count = 1;
			desc.SampleDesc.Quality = 0;
			desc.Usage = D3D11_USAGE_DEFAULT;
			desc.BindFlags = D3D11_BIND_DEPTH_STENCIL | D3D11_BIND_SHADER_RESOURCE;
			desc.CPUAccessFlags = 0;
			desc.MiscFlags = 0;

			hr = pD3DDevice->CreateTexture2D(&desc, NULL, &m_pDepthSurface);
			if (FAILED(hr))
			{
				panicF("Failed to create depth surface");
			}

			D3D11_DEPTH_STENCIL_VIEW_DESC depthDesc = {};
			depthDesc.Format = DXGI_FORMAT_D24_UNORM_S8_UINT; // View suitable for writing depth
			depthDesc.ViewDimension = D3D11_DSV_DIMENSION_TEXTURE2D;
			depthDesc.Texture2D.MipSlice = 0;

			hr = pD3DDevice->CreateDepthStencilView(m_pDepthSurface, &depthDesc, &m_pDepthSurfaceTargetView);
			if (FAILED(hr))
			{
				panicF("Failed to create depth surface render target view");
			}

			D3D11_SHADER_RESOURCE_VIEW_DESC srvDesc = {};
			srvDesc.Format = DXGI_FORMAT_R24_UNORM_X8_TYPELESS; // View suitable for decoding full 24bits of depth to red channel.
			srvDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
			srvDesc.Texture2D.MostDetailedMip = 0;
			srvDesc.Texture2D.MipLevels = 1;

			hr = pD3DDevice->CreateShaderResourceView(m_pDepthSurface, &srvDesc, &m_pDepthSurfaceSRV);
			if (FAILED(hr))
			{
				panicF("Failed to create depth surface SRV");
			}
		}
	}


private:

	PerFrameCBData m_perFrameCBData;
	ID3D11Buffer* m_pPerFrameCB = nullptr;

	PerDrawCBData m_perDrawCBData;
	ID3D11Buffer* m_pPerDrawCB = nullptr;

	ShaderSet m_meshShader;
	ShaderSet m_postEffectShader;

	Mesh m_meshArray[4];
	Texture m_textures[4];
	ID3D11SamplerState* m_pLinearMipSamplerState = nullptr;

	ColourPreset palettes[MAX_PALETTES];

	// Screen quad : for post effect pass.
	Mesh m_fullScreenQuad;

	// Post Effect Rendering Surfaces
	ID3D11Texture2D*		m_pColourSurface = nullptr;
	ID3D11RenderTargetView* m_pColourSurfaceTargetView = nullptr;
	ID3D11ShaderResourceView* m_pColourSurfaceSRV = nullptr;

	ID3D11Texture2D*		m_pDepthSurface = nullptr;
	ID3D11DepthStencilView* m_pDepthSurfaceTargetView = nullptr;
	ID3D11ShaderResourceView* m_pDepthSurfaceSRV = nullptr;

	v3 m_position;
	f32 m_size;

	// ----------- ImGui Variables -----------

	char* m_PostEffectNames[kNumberOfAlgorithms];
	int m_matSize = 2;
	int m_matSizeSq = 4;
	bool m_Ortho = true;
	int m_colourPresetSelected = 0, m_imageToUse = 2, m_postEffect = 0;
	std::string m_colourName = "Black and White";

	// ---------------------------------------
};

MinimalApp g_app;

FRAMEWORK_IMPLEMENT_MAIN(g_app, "Post-Processing Effects")
