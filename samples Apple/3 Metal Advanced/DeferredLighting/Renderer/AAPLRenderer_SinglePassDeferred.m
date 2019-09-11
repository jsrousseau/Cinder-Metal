/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of the renderer class which performs Metal setup and per frame rendering for a
 single pass deferred renderer used for iOS & tvOS devices
*/

#import "AAPLRenderer_SinglePassDeferred.h"

// Include header shared between C code here, which executes Metal API commands, and .metal files
#import "AAPLShaderTypes.h"

@implementation AAPLRenderer_SinglePassDeferred
{
    id <MTLRenderPipelineState> _lightPipelineState;

    MTLRenderPassDescriptor *_viewRenderPassDescriptor;

    MTKView *_view;
}

/// Perform single pass deferred renderer specific initialization
- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view
{
    self = [super initWithMetalKitView:view];

    if(self)
    {
        _view = view;
        self.GBuffersAttachedInFinalPass = YES;
        [self loadMetal];
        [self loadScene];
    }

    return self;
}

/// Create Metal render state objects specific to the single pass deferred renderer
- (void)loadMetal
{
    [super loadMetal];

    NSError *error;

    id <MTLLibrary> defaultLibrary = [self.device newDefaultLibrary];

    MTLRenderPipelineDescriptor * renderPipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    renderPipelineDescriptor.colorAttachments[AAPLRenderTargetLighting].pixelFormat = self.view.colorPixelFormat;
    renderPipelineDescriptor.colorAttachments[AAPLRenderTargetAlbedo].pixelFormat = self.albedo_specular_GBufferFormat;
    renderPipelineDescriptor.colorAttachments[AAPLRenderTargetNormal].pixelFormat =  self.normal_shadow_GBufferFormat;
    renderPipelineDescriptor.colorAttachments[AAPLRenderTargetDepth].pixelFormat =  self.depth_GBufferFormat;
    renderPipelineDescriptor.depthAttachmentPixelFormat =  self.view.depthStencilPixelFormat;
    renderPipelineDescriptor.stencilAttachmentPixelFormat =  self.view.depthStencilPixelFormat;

    // Setting unique descriptor values for light pipeline state
    {
        id <MTLFunction> lightVertexFunction = [defaultLibrary newFunctionWithName:@"deferred_point_lighting_vertex"];
        id <MTLFunction> lightFragmentFunction = [defaultLibrary newFunctionWithName:@"deferred_point_lighting_fragment"];

        renderPipelineDescriptor.label = @"Light";
        renderPipelineDescriptor.vertexFunction = lightVertexFunction;
        renderPipelineDescriptor.fragmentFunction = lightFragmentFunction;
        _lightPipelineState = [self.device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor
                                                                      error:&error];
        
        NSAssert(_lightPipelineState, @"Failed to create render pipeline state, error %@", error);
    }

    _viewRenderPassDescriptor = [MTLRenderPassDescriptor new];
    _viewRenderPassDescriptor.colorAttachments[AAPLRenderTargetAlbedo].loadAction = MTLLoadActionDontCare;
    _viewRenderPassDescriptor.colorAttachments[AAPLRenderTargetAlbedo].storeAction = MTLStoreActionDontCare;
    _viewRenderPassDescriptor.colorAttachments[AAPLRenderTargetNormal].loadAction = MTLLoadActionDontCare;
    _viewRenderPassDescriptor.colorAttachments[AAPLRenderTargetNormal].storeAction = MTLStoreActionDontCare;
    _viewRenderPassDescriptor.colorAttachments[AAPLRenderTargetDepth].loadAction = MTLLoadActionDontCare;
    _viewRenderPassDescriptor.colorAttachments[AAPLRenderTargetDepth].storeAction = MTLStoreActionDontCare;
    _viewRenderPassDescriptor.depthAttachment.loadAction = MTLLoadActionClear;
    _viewRenderPassDescriptor.depthAttachment.storeAction = MTLStoreActionDontCare;
    _viewRenderPassDescriptor.stencilAttachment.loadAction = MTLLoadActionClear;
    _viewRenderPassDescriptor.stencilAttachment.storeAction = MTLStoreActionDontCare;
    _viewRenderPassDescriptor.depthAttachment.clearDepth = 1.0;
    _viewRenderPassDescriptor.stencilAttachment.clearStencil = 0;
}

/// MTKViewDelegate Callback: Respond to device orientation change or other view size change
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    [super drawableSizeWillChange:size withGBufferStorageMode:MTLStorageModeMemoryless];

    _viewRenderPassDescriptor.colorAttachments[AAPLRenderTargetAlbedo].texture = self.albedo_specular_GBuffer;
    _viewRenderPassDescriptor.colorAttachments[AAPLRenderTargetNormal].texture = self.normal_shadow_GBuffer;
    _viewRenderPassDescriptor.colorAttachments[AAPLRenderTargetDepth].texture = self.depth_GBuffer;
}

/// Draw directional lighting, which, on with the single pass deferred renderer does not need
/// GBuffers set as textures as they do with the traditional deferred renderer
- (void)drawDirectionalLight:(nonnull id <MTLRenderCommandEncoder>)renderEncoder
{
    [renderEncoder pushDebugGroup:@"Draw Directional Light"];

    [super drawDirectionalLightCommon:renderEncoder];

    [renderEncoder popDebugGroup];
}

/// Setup single pass deferred renderer specific pipeline/  Then call common renderer code to apply
/// the point lights
- (void) drawPointLights:(id<MTLRenderCommandEncoder>)renderEncoder
{
    [renderEncoder pushDebugGroup:@"Draw Point Lights"];

    [renderEncoder setRenderPipelineState:_lightPipelineState];

    // Call common renderer after setting platform specific state in renderEncoder
    [super drawPointLightsCommon:renderEncoder];

    [renderEncoder popDebugGroup];
}

/// MTKViewDelegate callback: Called whenever the view needs to render
- (void) drawInMTKView:(nonnull MTKView *)view
{
    id<MTLCommandBuffer> commandBuffer = [self beginFrame];
    commandBuffer.label = @"Shadow commands";
    
    [super drawShadow:commandBuffer];

    // Commit commands so that Metal can begin working on non-drawable dependant work without
    // waiting for a drawable to become avaliable
    [commandBuffer commit];

    commandBuffer = [self beginDrawableCommands];
    commandBuffer.label = @"GBuffer & Lighting Commands";

    id<MTLTexture> drawableTexture = self.currentDrawableTexture;

    // The final pass can only render if a drawable is available, otherwise it needs to skip
    // rendering this frame.
    if(drawableTexture)
    {
        _viewRenderPassDescriptor.colorAttachments[AAPLRenderTargetLighting].texture = drawableTexture;
        _viewRenderPassDescriptor.depthAttachment.texture = self.view.depthStencilTexture;
        _viewRenderPassDescriptor.stencilAttachment.texture = self.view.depthStencilTexture;

        id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_viewRenderPassDescriptor];
        renderEncoder.label = @"Combined GBuffer & Lighting Pass";

        [super drawGBuffer:renderEncoder];

        [self drawDirectionalLight:renderEncoder];

        [super drawPointLightMask:renderEncoder];

        [self drawPointLights:renderEncoder];

        [super drawSky:renderEncoder];

        [super drawFairies:renderEncoder];

        [renderEncoder endEncoding];
    }

    [self endFrame:commandBuffer];
}

#if SUPPORT_BUFFER_EXAMINATION_MODE
/// Enable (or disable) buffer examination mode
- (void)toggleBufferExaminationMode:(AAPLExaminationMode)mode
{
    [super toggleBufferExaminationMode:mode];

    if(self.bufferExaminationMode)
    {
        // Clear the background of the GBuffer when examining buffers.  When rendering normally
        // clearing is wasteful, but when examining the buffers, the backgrounds appear corrupt
        // making unclear what's actually rendered to the buffers
        _viewRenderPassDescriptor.colorAttachments[AAPLRenderTargetAlbedo].loadAction = MTLLoadActionClear;
        _viewRenderPassDescriptor.colorAttachments[AAPLRenderTargetNormal].loadAction = MTLLoadActionClear;
        _viewRenderPassDescriptor.colorAttachments[AAPLRenderTargetDepth].loadAction = MTLLoadActionClear;

        // Store results of all buffers to examine them.  This is wasteful when rendering
        // normally, but necessary to present them on screen.
        _viewRenderPassDescriptor.colorAttachments[AAPLRenderTargetAlbedo].storeAction = MTLStoreActionStore;
        _viewRenderPassDescriptor.colorAttachments[AAPLRenderTargetNormal].storeAction = MTLStoreActionStore;
        _viewRenderPassDescriptor.colorAttachments[AAPLRenderTargetDepth].storeAction = MTLStoreActionStore;
        _viewRenderPassDescriptor.depthAttachment.storeAction = MTLStoreActionStore;
        _viewRenderPassDescriptor.stencilAttachment.storeAction = MTLStoreActionStore;

        // Force reallocation of GBuffer with MTLStorageModePrivate since buffer need to be written
        // to memory to render them later for examination
        [self mtkView:_view drawableSizeWillChange:_view.drawableSize];
    }
    else
    {
        // When exiting buffer examination mode, return to efficient state settings
        _viewRenderPassDescriptor.colorAttachments[AAPLRenderTargetAlbedo].loadAction = MTLLoadActionDontCare;
        _viewRenderPassDescriptor.colorAttachments[AAPLRenderTargetNormal].loadAction = MTLLoadActionDontCare;
        _viewRenderPassDescriptor.colorAttachments[AAPLRenderTargetDepth].loadAction = MTLLoadActionDontCare;
        _viewRenderPassDescriptor.colorAttachments[AAPLRenderTargetAlbedo].storeAction = MTLStoreActionDontCare;
        _viewRenderPassDescriptor.colorAttachments[AAPLRenderTargetNormal].storeAction = MTLStoreActionDontCare;
        _viewRenderPassDescriptor.colorAttachments[AAPLRenderTargetDepth].storeAction = MTLStoreActionDontCare;
        _viewRenderPassDescriptor.depthAttachment.storeAction = MTLStoreActionDontCare;
        _viewRenderPassDescriptor.stencilAttachment.storeAction = MTLStoreActionDontCare;

        // Force reallocation of GBuffer with MTLStorageModeMemoryless
        [self mtkView:_view drawableSizeWillChange:_view.drawableSize];
    }
}
#endif

@end
