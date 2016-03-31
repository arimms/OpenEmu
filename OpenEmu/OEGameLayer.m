//
//  OEGameLayer.m
//  OpenEmu
//
//  Created by Alexander Strange on 3/21/16.
//
//

@import OpenGL;
#import <OpenGL/gl.h>
#import "OEGameLayer.h"

/*
 * OE game rendering from game texture to drawable.
 * Experimental version to be run in core process.
 *
 * TODO: Is asynchronous drawing really the display rate, or always 60hz?
 * TODO: How do we combine this refresh and the game refresh?
 * TODO: Game texture should be SRGB texture if framebuffer is SRGB.
 * TODO: How to reduce code duplication for GL3 cores?
 * TODO: 2D cores should be Metal.
 * TODO: When paused, stop rendering.
 */

static NSRect FitGameRectIntoRectWithAspectSize(OEIntRect screenRect, NSRect bounds, OEIntSize aspectSize)
{
    return bounds;
}

// -- Private class for atomic params changing
@interface OEGameLayerPrivate : NSObject
{
    @public
    IOSurfaceRef ioSurface;

    OEIntSize    surfaceSize;
    GLuint       ioSurfaceTex;

    GLuint       quadVBO;
    GLuint       quadVAO;

    bool         linearScale;
}
@end

@implementation OEGameLayerPrivate
@end

// -- CALayer class

@interface OEGameLayer ()

@property (atomic) OEGameLayerPrivate *priv;

@end

@implementation OEGameLayer
{
    // Params for reconfiguring
    CGLContextObj _alternateCglCtx;     //< CGL share context used to compile shaders
}

- (instancetype)init
{
    self = [super init];

    /*
     * Use the "HDTV" colorspace. This is right for TV (probably) and better
     * than nothing for e.g. Gameboy on DCI-P3 screens. But "no correction" might be
     * what people are used to.
     */
    self.colorspace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_709);

    return self;
}

- (void)dealloc
{
    if (_alternateCglCtx)
        CGLDestroyContext(_alternateCglCtx);
}

#pragma mark Properties

- (void)setInput:(struct OEGameLayerInputParams)input
{
    if (memcmp(&input, &_input, sizeof(input)) == 0) return;

    _input = input;
    [self reconfigure];
}

- (void)setFilter:(struct OEGameLayerFilterParams)filter
{
    if (memcmp(&filter, &_filter, sizeof(filter)) == 0) return;

    _filter = filter;
    [self reconfigure];
}

- (void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];
    [self reconfigure];
}

#pragma mark Methods

- (void)reconfigure
{
    // Recalculate everything.
    // TODO: Split this up once it all works.

    if (_alternateCglCtx == nil) return;

    OEGameLayerPrivate *priv = [OEGameLayerPrivate new];
    CGLSetCurrentContext(_alternateCglCtx);

    // Lookup the IOSurface.
    priv->ioSurface = IOSurfaceLookup(_input.ioSurfaceID);

    // Prepare IOSurface texture.
    {
        glEnable(GL_TEXTURE_RECTANGLE_EXT);
        glGenTextures(1, &_priv->ioSurfaceTex);
        glBindTexture(GL_TEXTURE_RECTANGLE_EXT, _priv->ioSurfaceTex);
        glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

        priv->surfaceSize = (OEIntSize){.width = (int)IOSurfaceGetWidth(priv->ioSurface), .height = (int)IOSurfaceGetHeight(priv->ioSurface)};

        CGLTexImageIOSurface2D(_alternateCglCtx, GL_TEXTURE_RECTANGLE_EXT, GL_RGB8, priv->surfaceSize.width, priv->surfaceSize.height, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, priv->ioSurface, 0);
    }

    // Prepare filters.

    // Create VAO to hold game rect (pretending to be GL3 here)
    {
        glGenVertexArraysAPPLE(1, &priv->quadVAO);
        glBindVertexArrayAPPLE(priv->quadVBO);

        OEIntRect gameRect = OEIntRectMake(0, 0, _input.screenSize.width, _input.screenSize.height);
        NSRect texRect = FitGameRectIntoRectWithAspectSize(gameRect, self.bounds, _input.aspectSize);

        // Create Vertex Buffer for output rect.

        // Create Vertex Buffer for texture coordinates.
    }
    
    // Update.
    CGLSetCurrentContext(nil);
    self.priv = priv;
}

#pragma mark Overrides

-(CGLContextObj)copyCGLContextForPixelFormat:(CGLPixelFormatObj)pixelFormat
{
    CGLContextObj ret = [super copyCGLContextForPixelFormat:pixelFormat];
    CGLContextObj alt;

    // Create a share context for this thread.
    CGLCreateContext(pixelFormat, ret, &alt);

    if (_alternateCglCtx) CGLDestroyContext(_alternateCglCtx);
    _alternateCglCtx = alt;
    [self reconfigure];
    return ret;
}

-(void)drawInCGLContext:(CGLContextObj)glContext
            pixelFormat:(CGLPixelFormatObj)pixelFormat
           forLayerTime:(CFTimeInterval)timeInterval
            displayTime:(const CVTimeStamp *)timeStamp
{
    // Everything referenced in this method must be in 'priv' to keep it consistent.
    // (Assuming this doesn't run on the main thread in which case it doesn't matter...)

    OEGameLayerPrivate *priv = self.priv;

    CGLSetCurrentContext(glContext);
    glClear(GL_COLOR_BUFFER_BIT);
    glBindTexture(GL_TEXTURE_RECTANGLE_EXT, priv->ioSurfaceTex);

    glColor4f(1.0, 1.0, 1.0, 1.0);

}

@end
