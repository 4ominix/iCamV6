#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>
#import <VideoToolbox/VideoToolbox.h>
#import <notify.h>

static NSString *const kConfigPath = @"/var/jb/var/mobile/Library/VCNext/CameraConfig.plist";
static NSString *const kLeasePath = @"/var/jb/var/mobile/Library/VCNext/CapabilityLease.plist";
static NSString *const kStatusNotify = @"com.vcnext.camera.status.changed";

// Global Runtime State
static BOOL g_vcamEnabled = NO;
static BOOL g_colorSyncEnabled = NO;
static CGFloat g_colorSyncRed = 1.0;
static CGFloat g_colorSyncGreen = 1.0;
static CGFloat g_colorSyncBlue = 1.0;
static NSInteger g_deviceOrientation = 0; // 0, 90, 180, 270
static CGFloat g_zoomLevel = 1.0;
static NSString *g_selectedMediaPath = nil;

// Video playback engine
static AVPlayer *g_player = nil;
static AVPlayerItemVideoOutput *g_videoOutput = nil;
static CIContext *g_ciContext = nil;

static void reloadConfiguration() {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:kConfigPath];
    if (!dict) {
        g_vcamEnabled = NO;
        return;
    }
    
    // Check capability lease / license
    NSDictionary *lease = [NSDictionary dictionaryWithContentsOfFile:kLeasePath];
    if (!lease || ![lease[@"valid"] boolValue]) {
        // Disabled by safety policy if no valid lease
        g_vcamEnabled = NO;
        return;
    }

    g_vcamEnabled = [dict[@"enabled"] boolValue];
    g_colorSyncEnabled = [dict[@"colorSyncEnabled"] boolValue];
    g_colorSyncRed = [dict[@"colorSyncRed"] floatValue] ?: 1.0;
    g_colorSyncGreen = [dict[@"colorSyncGreen"] floatValue] ?: 1.0;
    g_colorSyncBlue = [dict[@"colorSyncBlue"] floatValue] ?: 1.0;
    g_deviceOrientation = [dict[@"orientation"] integerValue];
    g_zoomLevel = [dict[@"zoom"] floatValue] ?: 1.0;
    
    NSString *newPath = dict[@"mediaPath"];
    if (![newPath isEqualToString:g_selectedMediaPath]) {
        g_selectedMediaPath = [newPath copy];
        if (g_selectedMediaPath && [[NSFileManager defaultManager] fileExistsAtPath:g_selectedMediaPath]) {
            NSURL *url = [NSURL fileURLWithPath:g_selectedMediaPath];
            AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
            
            NSDictionary *pixBuffAttrs = @{
                (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)
            };
            g_videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixBuffAttrs];
            [item addOutput:g_videoOutput];
            
            g_player = [AVPlayer playerWithPlayerItem:item];
            g_player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
            [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
                                                              object:item
                                                               queue:[NSOperationQueue mainQueue]
                                                          usingBlock:^(NSNotification *note) {
                [g_player seekToTime:kCMTimeZero];
                [g_player play];
            }];
            [g_player play];
        }
    }
}

static CVPixelBufferRef applyColorSyncAndTransform(CVPixelBufferRef sourceBuffer) {
    if (!g_ciContext) {
        g_ciContext = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer: @(NO)}];
    }
    
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:sourceBuffer];
    
    // 1. Color Sync Filter (Matrix color grading matching real environment)
    if (g_colorSyncEnabled) {
        CIFilter *colorFilter = [CIFilter filterWithName:@"CIColorMatrix"];
        [colorFilter setValue:ciImage forKey:kCIInputImageKey];
        [colorFilter setValue:[CIVector vectorWithX:g_colorSyncRed Y:0 Z:0 W:0] forKey:@"inputRVector"];
        [colorFilter setValue:[CIVector vectorWithX:0 Y:g_colorSyncGreen Z:0 W:0] forKey:@"inputGVector"];
        [colorFilter setValue:[CIVector vectorWithX:0 Y:0 Z:g_colorSyncBlue W:0] forKey:@"inputBVector"];
        ciImage = colorFilter.outputImage ?: ciImage;
    }
    
    // 2. Zoom & Transform
    if (g_zoomLevel > 1.01) {
        CGRect extent = ciImage.extent;
        CGFloat w = extent.size.width / g_zoomLevel;
        CGFloat h = extent.size.height / g_zoomLevel;
        CGFloat x = (extent.size.width - w) / 2.0;
        CGFloat y = (extent.size.height - h) / 2.0;
        ciImage = [ciImage imageByCroppingToRect:CGRectMake(x, y, w, h)];
        ciImage = [ciImage imageByApplyingTransform:CGAffineTransformMakeScale(g_zoomLevel, g_zoomLevel)];
    }
    
    // 3. Render back to CVPixelBuffer
    size_t width = CVPixelBufferGetWidth(sourceBuffer);
    size_t height = CVPixelBufferGetHeight(sourceBuffer);
    
    CVPixelBufferRef destBuffer = NULL;
    NSDictionary *options = @{
        (id)kCVPixelBufferIOSurfacePropertiesKey: @{},
        (id)kCVPixelBufferCGImageCompatibilityKey: @(YES),
        (id)kCVPixelBufferCGBitmapContextCompatibilityKey: @(YES)
    };
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)options, &destBuffer);
    if (status == kCVReturnSuccess && destBuffer) {
        [g_ciContext render:ciImage toCVPixelBuffer:destBuffer];
        return destBuffer;
    }
    return NULL;
}

%hook AVCaptureVideoDataOutput

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (!g_vcamEnabled || !g_videoOutput || !g_player) {
        %orig(output, sampleBuffer, connection);
        return;
    }
    
    CMTime itemTime = [g_player currentTime];
    if (![g_videoOutput hasNewPixelBufferForItemTime:itemTime]) {
        %orig(output, sampleBuffer, connection);
        return;
    }
    
    CVPixelBufferRef fakePixelBuffer = [g_videoOutput copyPixelBufferForItemTime:itemTime itemTimeForDisplay:NULL];
    if (!fakePixelBuffer) {
        %orig(output, sampleBuffer, connection);
        return;
    }
    
    // Apply real-time Color Sync & Transform
    CVPixelBufferRef processedBuffer = applyColorSyncAndTransform(fakePixelBuffer);
    CVPixelBufferRef finalBuffer = processedBuffer ? processedBuffer : fakePixelBuffer;
    
    // Create new CMSampleBuffer preserving original timestamps
    CMSampleTimingInfo timingInfo;
    CMSampleBufferGetSampleTimingInfo(sampleBuffer, 0, &timingInfo);
    
    CMVideoFormatDescriptionRef formatDesc = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, finalBuffer, &formatDesc);
    
    CMSampleBufferRef newSampleBuffer = NULL;
    OSStatus err = CMSampleBufferCreateReadyWithImageBuffer(
        kCFAllocatorDefault,
        finalBuffer,
        formatDesc,
        &timingInfo,
        &newSampleBuffer
    );
    
    if (err == noErr && newSampleBuffer) {
        %orig(output, newSampleBuffer, connection);
        CFRelease(newSampleBuffer);
    } else {
        %orig(output, sampleBuffer, connection);
    }
    
    if (formatDesc) CFRelease(formatDesc);
    if (processedBuffer) CVPixelBufferRelease(processedBuffer);
    CVPixelBufferRelease(fakePixelBuffer);
}

%end

%ctor {
    @autoreleasepool {
        reloadConfiguration();
        
        // Listen for IPC changes from App and SpringBoard Overlay
        int token = 0;
        notify_register_dispatch([kStatusNotify UTF8String], &token, dispatch_get_main_queue(), ^(int t) {
            reloadConfiguration();
        });
    }
}
