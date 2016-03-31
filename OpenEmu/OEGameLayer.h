//
//  OEGameLayer.h
//  OpenEmu
//
//  Created by Alexander Strange on 3/21/16.
//
//

@import Cocoa;
@import QuartzCore;

#import "OEGameCoreHelper.h"

struct OEGameLayerInputParams {
    OEIntSize screenSize;
    OEIntSize aspectSize;
    IOSurfaceID ioSurfaceID;
};

struct OEGameLayerFilterParams {
    bool linearFilter;
};

@interface OEGameLayer : CAOpenGLLayer

@property (nonatomic) struct OEGameLayerInputParams  input;
@property (nonatomic) struct OEGameLayerFilterParams filter;

@end
